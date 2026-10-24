import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lorcarcana/features/cards/lorcana_card.dart';
import 'package:lorcarcana/features/deck/deck_rules.dart';
import 'package:lorcarcana/features/match/effects/effect_script.dart';
import 'package:lorcarcana/features/match/match_table.dart';
import 'package:lorcarcana/features/practice/practice_deck.dart';

void main() {
  test('lê uma carta no formato LorcanaJSON 2', () {
    final payload = rowsFromLorcanaJson('''
      {
        "metadata": {"formatVersion": "2.4.0", "generatedOn": "2026-10-16T00:00:00"},
        "sets": {"1": {"name": "Teste"}},
        "cards": [{
          "id": 7,
          "name": "Lanterna",
          "fullName": "Lanterna",
          "simpleName": "lanterna",
          "type": "Character",
          "cost": 3,
          "color": "Amber",
          "inkwell": true,
          "strength": 2,
          "willpower": 4,
          "lore": 1,
          "subtypes": ["Storyborn"],
          "fullText": "Singer 5",
          "setCode": "1",
          "rarity": "Common",
          "abilities": [
            {"type": "keyword", "keyword": "Singer", "keywordValueNumber": 5},
            {"type": "activated", "name": "LUZ", "costsText": "⟳", "effect": "Draw a card."}
          ],
          "allowedInFormats": {
            "Core": {"allowed": true},
            "Infinity": {"allowed": false}
          }
        }]
      }
    ''');
    final rows = payload['rows'] as List;
    final card = LorcanaCard.fromRow(Map<String, Object?>.from(rows.single as Map));

    expect(card.fullName, 'Lanterna');
    expect(card.setName, 'Teste');
    expect(card.inks, [Ink.amber]);
    expect(card.keywordNumber('Singer'), 5);
    expect(card.abilities.single.exertCost, isTrue);
    expect(card.coreLegal, isTrue);
    expect(card.infinityLegal, isFalse);
  });

  test('reconhece efeitos curtos e deixa o resto para a mesa', () {
    final effects = scriptFromTexts(const [
      'Deal 2 damage to chosen character.',
      'Draw a card. You may banish chosen character with Evasive.',
      'Look at the top 4 cards of your deck.',
    ]);

    expect(effects[0].op, ScriptOp.damage);
    expect(effects[0].amount, 2);
    expect(effects[1].op, ScriptOp.draw);
    expect(effects[2].op, ScriptOp.notice);
    expect(effects[3].op, ScriptOp.notice);
  });

  test('o primeiro jogador não compra no turno 1', () {
    final table = _table();
    expect(table.players[0].hand, hasLength(7));
    expect(table.players[0].deck, hasLength(23));
    table.mulligan(0, const [0]);
    table.mulligan(1, const []);

    expect(table.phase, Phase.main);
    expect(table.players[0].hand, hasLength(7));
    expect(table.players[0].deck, hasLength(23));
    table.endTurn();
    expect(table.players[1].hand, hasLength(8));
    table.endTurn();
    expect(table.players[0].hand, hasLength(8));
  });

  test('personagem entra secando e explora no turno seguinte', () {
    final table = _table();
    table.skipToMain();
    table.addInk(0, 3);
    table.players[0].hand.add(1);
    table.playFromHand(table.players[0].hand.length - 1);

    final played = table.players[0].play.single;
    expect(played.drying, isTrue);
    expect(table.canQuest(played.instanceId), isFalse);
    table.endTurn();
    table.endTurn();
    expect(played.drying, isFalse);
    table.quest(played.instanceId);
    expect(table.players[0].lore, 1);
    expect(played.exerted, isTrue);
  });

  test('desafio causa dano ao mesmo tempo e Resist reduz', () {
    final cards = _cards();
    cards[4] = _card(
      4,
      keywords: const [CardKeyword('Resist', 2)],
      willpower: 5,
      strength: 2,
    );
    final table = _table(cards: cards);
    table.skipToMain();
    final attacker = table.spawn(0, 1);
    final defender = table.spawn(1, 4, exerted: true);
    table.challenge(attacker.instanceId, defender.instanceId);

    expect(defender.damage, 1);
    expect(table.findPlayed(defender.instanceId), isNotNull);
    expect(attacker.damage, 2);
  });

  test('Evasive, Rush, Bodyguard e local', () {
    final cards = _cards();
    cards[2] = _card(2, keywords: const [CardKeyword('Evasive')]);
    cards[3] = _card(3, keywords: const [CardKeyword('Rush')]);
    cards[4] = _card(4, keywords: const [CardKeyword('Bodyguard')]);
    cards[5] = _card(
      5,
      kind: CardKind.location,
      strength: null,
      lore: 2,
      willpower: 4,
      moveCost: 1,
    );
    final table = _table(cards: cards);
    table.skipToMain();
    final plain = table.spawn(0, 1);
    table.spawn(1, 2, exerted: true);
    expect(table.legalChallengeTargets(plain.instanceId), isEmpty);

    final rusher = table.spawn(0, 3, drying: true);
    final guard = table.spawn(1, 4, exerted: true);
    final other = table.spawn(1, 1, exerted: true);
    final location = table.spawn(1, 5);
    final targets = table.legalChallengeTargets(rusher.instanceId);
    expect(targets, contains(guard.instanceId));
    expect(targets, isNot(contains(other.instanceId)));
    expect(targets, contains(location.instanceId));

    table.challenge(rusher.instanceId, location.instanceId);
    expect(rusher.damage, 0);
    expect(location.damage, 3);
  });

  test('Shift, canção e dano de ação', () {
    final cards = _cards();
    cards[1] = _card(1, name: 'Hades', fullName: 'Hades - Base', cost: 2);
    cards[2] = _card(
      2,
      name: 'Hades',
      fullName: 'Hades - Rei',
      cost: 6,
      strength: 5,
      willpower: 6,
      keywords: const [CardKeyword('Shift', 2)],
    );
    cards[3] = _card(
      3,
      name: 'Canto',
      kind: CardKind.action,
      cost: 4,
      strength: null,
      willpower: null,
      lore: null,
      subtypes: const ['Song'],
      effects: const ['Draw a card.'],
    );
    cards[4] = _card(4, cost: 1, keywords: const [CardKeyword('Singer', 5)]);
    cards[6] = _card(
      6,
      name: 'Golpe',
      kind: CardKind.action,
      cost: 1,
      strength: null,
      willpower: null,
      lore: null,
      effects: const ['Deal 2 damage to chosen character.'],
    );
    final table = _table(cards: cards);
    table.skipToMain();
    final host = table.spawn(0, 1, drying: true, damage: 1);
    table.addInk(0, 4);
    table.players[0].hand
      ..clear()
      ..add(2);
    table.playFromHand(0, shiftOnto: host.instanceId);
    expect(host.cardId, 2);
    expect(host.under, [1]);
    expect(host.drying, isTrue);
    expect(host.damage, 1);
    expect(table.player.readyInk, 2);

    final singer = table.spawn(0, 4);
    table.players[0].deck.insert(0, 1);
    table.players[0].hand.add(3);
    final before = table.players[0].hand.length;
    table.playFromHand(table.players[0].hand.length - 1, singer: singer.instanceId);
    expect(singer.exerted, isTrue);
    expect(table.players[0].hand, hasLength(before));

    final foe = table.spawn(1, 1);
    table.players[0].hand.add(6);
    table.playFromHand(table.players[0].hand.length - 1);
    table.answerEffect(foe.instanceId);
    expect(foe.damage, 2);
  });

  test('vinte de lore vence e deck vazio no fim do turno perde', () {
    final table = _table();
    table.skipToMain();
    table.players[0].lore = 19;
    final played = table.spawn(0, 1);
    table.quest(played.instanceId);
    expect(table.winnerSeat, 0);

    final other = _table();
    other.skipToMain();
    other.players[0].deck.clear();
    other.endTurn();
    expect(other.winnerSeat, 1);
  });

  test('Reckless não explora e segura o fim do turno', () {
    final cards = _cards();
    cards[2] = _card(2, keywords: const [CardKeyword('Reckless')], lore: 2);
    final table = _table(cards: cards);
    table.skipToMain();
    final reckless = table.spawn(0, 2);
    table.spawn(1, 1, exerted: true);
    expect(table.canQuest(reckless.instanceId), isFalse);
    expect(
      () => table.endTurn(),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('deck construído limita cópias, tintas e tamanho', () {
    final amber = _card(1, inks: const [Ink.amber]);
    final ruby = _card(2, name: 'Brasa', inks: const [Ink.ruby]);
    final dual = _card(
      3,
      name: 'Ponte',
      inks: const [Ink.amber, Ink.steel],
    );
    final cards = {1: amber, 2: ruby, 3: dual};
    expect(
      DeckRules.issues([1, 1, 1, 1], cards, format: PlayFormat.core),
      isNotEmpty,
    );
    expect(
      DeckRules.issues(List<int>.filled(60, 1), cards, format: PlayFormat.core),
      contains('Guarda tem 60 cópias. O máximo é 4.'),
    );
    expect(
      DeckRules.issues(
        [...List<int>.filled(30, 1), ...List<int>.filled(30, 3)],
        cards,
        format: PlayFormat.core,
      ).any((issue) => issue.contains('tintas')),
      isFalse,
    );
    expect(
      DeckRules.issues(
        [...List<int>.filled(20, 1), ...List<int>.filled(20, 2), ...List<int>.filled(20, 3)],
        cards,
        format: PlayFormat.infinity,
      ).any((issue) => issue.contains('tintas')),
      isTrue,
    );
  });

  test('o treino monta até 60 cartas em no máximo duas tintas', () {
    final cards = <LorcanaCard>[];
    for (var id = 1; id <= 40; id++) {
      cards.add(
        _card(
          id,
          name: 'Carta $id',
          fullName: 'Carta $id',
          cost: id % 6,
          inks: [id.isEven ? Ink.ruby : Ink.amber],
          coreLegal: true,
        ),
      );
    }
    final deck = PracticeDeck.build(cards, _StableRandom());
    expect(deck.ids, hasLength(60));
    final inks = <Ink>{};
    for (final id in deck.ids) {
      inks.addAll(cards[id - 1].inks);
    }
    expect(inks.length, lessThanOrEqualTo(2));
  });
}

Map<int, LorcanaCard> _cards() {
  return {for (final card in [_card(1)]) card.id: card};
}

LorcanaCard _card(
  int id, {
  String name = 'Guarda',
  String? fullName,
  CardKind kind = CardKind.character,
  int cost = 1,
  int? strength = 3,
  int? willpower = 3,
  int? lore = 1,
  int? moveCost,
  List<Ink> inks = const [Ink.amber],
  List<CardKeyword> keywords = const [],
  List<String> subtypes = const [],
  List<String> effects = const [],
  bool coreLegal = true,
}) {
  return LorcanaCard(
    id: id,
    name: name,
    fullName: fullName ?? name,
    simpleName: (fullName ?? name).toLowerCase(),
    names: [name],
    kind: kind,
    inks: inks,
    cost: cost,
    inkwell: true,
    strength: strength,
    willpower: willpower,
    lore: lore,
    moveCost: moveCost,
    keywords: keywords,
    subtypes: subtypes,
    effects: effects,
    coreLegal: coreLegal,
    infinityLegal: true,
  );
}

MatchTable _table({Map<int, LorcanaCard>? cards}) {
  final catalog = cards ?? _cards();
  return MatchTable.start(
    deckA: List<int>.filled(30, 1),
    deckB: List<int>.filled(30, 1),
    catalog: catalog,
    random: _StableRandom(),
  );
}

class _StableRandom implements Random {
  int _next = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => _next++ % max;
}
