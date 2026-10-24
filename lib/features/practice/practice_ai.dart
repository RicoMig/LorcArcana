import 'dart:math';

import '../cards/lorcana_card.dart';
import '../match/match_table.dart';

class PracticeAi {
  bool step(MatchTable table) {
    if (table.over) return false;
    final choice = table.choice;
    if (choice != null) {
      _answer(table, choice);
      return true;
    }
    if (table.phase != Phase.main) return false;
    final board = table.player;
    if (!board.inkedThisTurn) {
      final index = _inkIndex(table, board);
      if (index != null) {
        table.ink(index);
        return true;
      }
    }
    final play = _play(table, board);
    if (play != null) {
      table.playFromHand(play.index, shiftOnto: play.shiftOnto);
      return true;
    }
    final attack = _attack(table);
    if (attack != null) {
      table.challenge(attack.attacker, attack.target);
      return true;
    }
    final quest = _quest(table);
    if (quest != null) {
      table.quest(quest);
      return true;
    }
    return false;
  }

  void _answer(MatchTable table, Choice choice) {
    switch (choice.kind) {
      case ChoiceKind.mulligan:
        table.mulligan(choice.seat, const []);
      case ChoiceKind.bodyguard:
        final allies = table.player.play.where((played) {
          return table.card(played.cardId).kind == CardKind.character;
        });
        table.answerBodyguard(allies.isNotEmpty);
      case ChoiceKind.support:
        table.answerSupport(_preferOpponent(table, choice.targets) ?? _first(choice.targets));
      case ChoiceKind.effect:
        final effect = choice.effect;
        if (effect != null && effect.optional && choice.targets.isEmpty) {
          table.answerEffect(null);
          return;
        }
        table.answerEffect(_preferOpponent(table, choice.targets));
      case ChoiceKind.notice:
        table.acknowledge();
    }
  }

  int? _inkIndex(MatchTable table, PlayerBoard board) {
    final candidates = <int>[];
    for (var index = 0; index < board.hand.length; index++) {
      if (table.card(board.hand[index]).inkwell) candidates.add(index);
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final left = table.card(board.hand[a]);
      final right = table.card(board.hand[b]);
      if (left.kind == CardKind.action && right.kind != CardKind.action) return -1;
      if (right.kind == CardKind.action && left.kind != CardKind.action) return 1;
      return right.cost.compareTo(left.cost);
    });
    final chosen = table.card(board.hand[candidates.first]);
    final characters = board.hand.where((id) {
      return table.card(id).kind == CardKind.character;
    });
    final boardCharacters = board.play.where((played) {
      return table.card(played.cardId).kind == CardKind.character;
    });
    if (chosen.kind == CardKind.character &&
        chosen.cost <= 2 &&
        characters.length == 1 &&
        boardCharacters.isEmpty &&
        board.inkwell.isNotEmpty) {
      return null;
    }
    return candidates.first;
  }

  _Play? _play(MatchTable table, PlayerBoard board) {
    _Play? best;
    for (var index = 0; index < board.hand.length; index++) {
      final card = table.card(board.hand[index]);
      if (card.kind == CardKind.action) continue;
      final shiftTargets = table.legalShiftTargets(card);
      final shiftCost = card.keywordNumber('Shift');
      final useShift =
          shiftCost != null &&
          shiftTargets.isNotEmpty &&
          shiftCost <= board.readyInk &&
          shiftCost < card.cost;
      final cost = useShift ? shiftCost : card.cost;
      if (cost > board.readyInk) continue;
      final score =
          (card.lore ?? 0) * 4 +
          (card.willpower ?? 0) +
          (card.strength ?? 0) +
          (card.kind == CardKind.character ? 3 : 0) -
          cost +
          (useShift ? 5 : 0);
      if (best == null || score > best.score) {
        best = _Play(
          index: index,
          shiftOnto: useShift ? shiftTargets.first : null,
          score: score,
        );
      }
    }
    return best;
  }

  _Attack? _attack(MatchTable table) {
    _Attack? best;
    for (final played in table.player.play) {
      final targets = table.legalChallengeTargets(played.instanceId);
      if (targets.isEmpty) continue;
      final reckless = table.card(played.cardId).hasKeyword('Reckless');
      for (final targetId in targets) {
        final score = _attackScore(table, played, targetId, reckless: reckless);
        if (best == null || score > best.score) {
          best = _Attack(
            attacker: played.instanceId,
            target: targetId,
            score: score,
          );
        }
      }
    }
    if (best == null || best.score < 1) return null;
    return best;
  }

  int _attackScore(
    MatchTable table,
    PlayedCard attacker,
    int targetId, {
    required bool reckless,
  }) {
    final target = table.findPlayed(targetId)!;
    final atkCard = table.card(attacker.cardId);
    final defCard = table.card(target.cardId);
    final atk =
        max(0, (atkCard.strength ?? 0) + attacker.strengthBonus) +
        (atkCard.keywordNumber('Challenger') ?? 0);
    final resist = defCard.keywordNumber('Resist') ?? 0;
    final dealt = max(0, atk - resist);
    final banishes = dealt >= (defCard.willpower ?? 0) - target.damage;
    final back = defCard.kind == CardKind.location
        ? 0
        : max(0, (defCard.strength ?? 0) + target.strengthBonus);
    final ourResist = atkCard.keywordNumber('Resist') ?? 0;
    final taken = max(0, back - ourResist);
    final dies = taken >= (atkCard.willpower ?? 0) - attacker.damage;
    if (banishes && !dies) return 80 + (defCard.lore ?? 0) * 5;
    if (banishes) return 25;
    if (!dies && dealt > 0) return 8;
    return reckless ? 1 : -1;
  }

  int? _quest(MatchTable table) {
    int? best;
    var lore = -1;
    for (final played in table.player.play) {
      if (!table.canQuest(played.instanceId)) continue;
      final card = table.card(played.cardId);
      final value = card.lore ?? 0;
      if (value <= 0 && !card.hasKeyword('Adventurous')) continue;
      if (value > lore) {
        lore = value;
        best = played.instanceId;
      }
    }
    return best;
  }

  int? _preferOpponent(MatchTable table, List<int> targets) {
    for (final id in targets) {
      if (table.seatOf(id) != table.active) return id;
    }
    return _first(targets);
  }

  int? _first(List<int> targets) => targets.isEmpty ? null : targets.first;
}

class _Play {
  const _Play({required this.index, required this.shiftOnto, required this.score});

  final int index;
  final int? shiftOnto;
  final int score;
}

class _Attack {
  const _Attack({
    required this.attacker,
    required this.target,
    required this.score,
  });

  final int attacker;
  final int target;
  final int score;
}
