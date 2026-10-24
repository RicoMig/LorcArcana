import 'dart:math';

import '../cards/lorcana_card.dart';
import 'effects/effect_script.dart';

class GameRuleException implements Exception {
  GameRuleException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum Phase { mulligan, ready, set, draw, main }

enum ChoiceKind { mulligan, bodyguard, support, effect, notice }

class Choice {
  const Choice({
    required this.kind,
    required this.seat,
    required this.prompt,
    this.handIndex,
    this.instanceId,
    this.singer,
    this.effect,
    this.targets = const [],
  });

  final ChoiceKind kind;
  final int seat;
  final String prompt;
  final int? handIndex;
  final int? instanceId;
  final int? singer;
  final ScriptedEffect? effect;
  final List<int> targets;

  factory Choice.mulligan(int seat) {
    return Choice(
      kind: ChoiceKind.mulligan,
      seat: seat,
      prompt:
          'Devolva qualquer quantidade ao fundo do deck, ou fique com a mão.',
    );
  }
}

class InkSlot {
  InkSlot(this.cardId, {this.exerted = false});

  final int cardId;
  bool exerted;
}

class PlayedCard {
  PlayedCard({
    required this.instanceId,
    required this.cardId,
    this.exerted = false,
    this.drying = false,
    this.damage = 0,
  });

  final int instanceId;
  int cardId;
  final List<int> under = [];
  final List<int> facedown = [];
  bool exerted;
  bool drying;
  int damage;
  int strengthBonus = 0;
  int? atLocation;
  bool boostUsed = false;
}

class PlayerBoard {
  PlayerBoard({required this.name, required List<int> deck})
    : deck = List<int>.of(deck);

  final String name;
  final List<int> deck;
  final List<int> hand = [];
  final List<InkSlot> inkwell = [];
  final List<PlayedCard> play = [];
  final List<int> discard = [];
  int lore = 0;
  bool inkedThisTurn = false;

  int get readyInk => inkwell.where((ink) => !ink.exerted).length;
}

class MatchTable {
  MatchTable.start({
    required List<int> deckA,
    required List<int> deckB,
    required this.catalog,
    Random? random,
    String nameA = 'Jogador 1',
    String nameB = 'Jogador 2',
  }) : random = random ?? Random() {
    players = [
      PlayerBoard(name: nameA, deck: List<int>.of(deckA)..shuffle(this.random)),
      PlayerBoard(name: nameB, deck: List<int>.of(deckB)..shuffle(this.random)),
    ];
    for (final player in players) {
      _drawCards(player, 7);
    }
    phase = Phase.mulligan;
    choice = Choice.mulligan(0);
    _log('Cada jogador compra 7. Uma troca de mão, na ordem da vez.');
  }

  final Map<int, LorcanaCard> catalog;
  final Random random;
  late final List<PlayerBoard> players;
  int active = 0;
  int turn = 1;
  Phase phase = Phase.mulligan;
  Choice? choice;
  int? winnerSeat;
  final List<String> log = [];
  final List<ScriptedEffect> effectQueue = [];
  bool skipFirstDraw = true;
  int _next = 1;

  bool get over => winnerSeat != null;

  PlayerBoard get player => players[active];

  LorcanaCard card(int id) {
    final found = catalog[id];
    if (found == null) {
      throw GameRuleException('A carta $id não está na base.');
    }
    return found;
  }

  PlayedCard? findPlayed(int instanceId) {
    for (final board in players) {
      for (final played in board.play) {
        if (played.instanceId == instanceId) return played;
      }
    }
    return null;
  }

  int seatOf(int instanceId) {
    for (var seat = 0; seat < players.length; seat++) {
      if (players[seat].play.any((played) => played.instanceId == instanceId)) {
        return seat;
      }
    }
    throw GameRuleException('Essa carta não está em jogo.');
  }

  void mulligan(int seat, List<int> bottomIndexes) {
    final current = choice;
    if (phase != Phase.mulligan ||
        current?.kind != ChoiceKind.mulligan ||
        current!.seat != seat) {
      throw GameRuleException('Não é a vez de trocar a mão.');
    }
    final board = players[seat];
    final indexes = bottomIndexes.toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final returned = <int>[];
    for (final index in indexes) {
      if (index < 0 || index >= board.hand.length) {
        throw GameRuleException('Essa carta não está na mão.');
      }
      returned.add(board.hand.removeAt(index));
    }
    board.deck.addAll(returned);
    final drawn = _drawCards(board, 7 - board.hand.length);
    if (returned.isNotEmpty) {
      board.deck.shuffle(random);
      _log('${board.name} devolve ${returned.length} e compra $drawn.');
    } else {
      _log('${board.name} fica com a mão.');
    }
    if (seat == 0) {
      choice = Choice.mulligan(1);
      return;
    }
    choice = null;
    active = 0;
    _beginTurn();
  }

  void ink(int handIndex) {
    _ensureMain();
    final board = player;
    if (board.inkedThisTurn) {
      throw GameRuleException('Você já tintou neste turno.');
    }
    final id = _handCard(board, handIndex);
    final played = card(id);
    if (!played.inkwell) {
      throw GameRuleException('Essa carta não tem o símbolo do tinteiro.');
    }
    board.hand.removeAt(handIndex);
    board.inkwell.add(InkSlot(id));
    board.inkedThisTurn = true;
    _log('${board.name} revela ${played.fullName} e tinge.');
  }

  void playFromHand(
    int handIndex, {
    int? shiftOnto,
    int? singer,
    bool? enterExerted,
  }) {
    _ensureMain();
    final board = player;
    final id = _handCard(board, handIndex);
    final entering = card(id);
    if (entering.kind == CardKind.character &&
        entering.hasKeyword('Bodyguard') &&
        shiftOnto == null &&
        enterExerted == null) {
      choice = Choice(
        kind: ChoiceKind.bodyguard,
        seat: active,
        handIndex: handIndex,
        singer: singer,
        prompt: '${entering.fullName} pode entrar exercido.',
      );
      return;
    }
    if (shiftOnto != null) {
      _validateShift(entering, shiftOnto);
      _pay(entering.keywordNumber('Shift') ?? 0);
    } else if (singer != null) {
      _validateSinger(entering, singer);
    } else {
      _pay(entering.cost);
    }
    board.hand.removeAt(handIndex);
    if (shiftOnto != null) {
      final host = _must(shiftOnto);
      host.under.add(host.cardId);
      host.cardId = id;
      _log('${entering.fullName} entra por Shift.');
      _sweep();
      _noteTriggers(entering);
      return;
    }
    if (entering.kind == CardKind.character) {
      board.play.add(
        PlayedCard(
          instanceId: _next++,
          cardId: id,
          exerted: enterExerted ?? false,
          drying: true,
        ),
      );
      _log(
        enterExerted == true
            ? '${entering.fullName} entra exercida e secando.'
            : '${entering.fullName} entra secando.',
      );
      _noteTriggers(entering);
      return;
    }
    if (entering.kind == CardKind.item || entering.kind == CardKind.location) {
      board.play.add(PlayedCard(instanceId: _next++, cardId: id));
      _log('${entering.fullName} entra em jogo.');
      _noteTriggers(entering);
      return;
    }
    board.discard.add(id);
    if (singer != null) {
      _must(singer).exerted = true;
      _log(
        '${card(singer).fullName} canta ${entering.fullName}.',
      );
    } else {
      _log('${board.name} joga ${entering.fullName}.');
    }
    final texts = entering.effects.isNotEmpty
        ? entering.effects
        : [entering.fullText];
    effectQueue.addAll(scriptFromTexts(texts));
    _pump();
  }

  void answerBodyguard(bool exerted) {
    final current = choice;
    if (current?.kind != ChoiceKind.bodyguard || current!.handIndex == null) {
      throw GameRuleException('Não há Bodyguard esperando escolha.');
    }
    choice = null;
    playFromHand(
      current.handIndex!,
      singer: current.singer,
      enterExerted: exerted,
    );
  }

  void cancelBodyguard() {
    if (choice?.kind != ChoiceKind.bodyguard) {
      throw GameRuleException('Não há entrada de Bodyguard para cancelar.');
    }
    choice = null;
  }

  void quest(int instanceId) {
    _ensureMain();
    final played = _must(instanceId);
    if (!canQuest(instanceId)) {
      throw GameRuleException('Esse personagem não pode explorar.');
    }
    played.exerted = true;
    final current = card(played.cardId);
    final gained = max(0, current.lore ?? 0);
    _gainLore(active, gained);
    _log('${current.fullName} explora e ganha $gained de lore.');
    if (over || !current.hasKeyword('Support')) return;
    final allies = player.play
        .where(
          (other) =>
              other.instanceId != instanceId &&
              card(other.cardId).kind == CardKind.character,
        )
        .map((other) => other.instanceId)
        .toList();
    if (allies.isEmpty) return;
    choice = Choice(
      kind: ChoiceKind.support,
      seat: active,
      instanceId: instanceId,
      targets: allies,
      prompt: 'Support: some a Força de ${current.fullName} a outro personagem.',
    );
  }

  void answerSupport(int? targetId) {
    final current = choice;
    if (current?.kind != ChoiceKind.support || current!.instanceId == null) {
      throw GameRuleException('Não há Support esperando escolha.');
    }
    choice = null;
    if (targetId == null) {
      _log('Support ignorado.');
      return;
    }
    if (!current.targets.contains(targetId)) {
      throw GameRuleException('Esse personagem não pode receber Support.');
    }
    final bonus = _strength(_must(current.instanceId!), challenging: false);
    _must(targetId).strengthBonus += bonus;
    _log('Support soma $bonus de Força neste turno.');
  }

  void challenge(int attackerId, int defenderId) {
    _ensureMain();
    final attacker = _must(attackerId);
    if (seatOf(attackerId) != active) {
      throw GameRuleException('Só o jogador ativo desafia.');
    }
    if (!legalChallengeTargets(attackerId).contains(defenderId)) {
      throw GameRuleException('Esse alvo não pode ser desafiado.');
    }
    final defender = _must(defenderId);
    attacker.exerted = true;
    final atkCard = card(attacker.cardId);
    final defCard = card(defender.cardId);
    final atk = _strength(attacker, challenging: true);
    final def = defCard.kind == CardKind.location
        ? 0
        : _strength(defender, challenging: false);
    _deal(defender, atk);
    if (defCard.kind != CardKind.location) _deal(attacker, def);
    _log('${atkCard.fullName} desafia ${defCard.fullName}.');
    _sweep();
  }

  void move(int characterId, int locationId) {
    _ensureMain();
    final character = _must(characterId);
    final location = _must(locationId);
    if (seatOf(characterId) != active || seatOf(locationId) != active) {
      throw GameRuleException('Mova um personagem seu para um local seu.');
    }
    final who = card(character.cardId);
    final where = card(location.cardId);
    if (who.kind != CardKind.character || where.kind != CardKind.location) {
      throw GameRuleException('Só um personagem se move para um local.');
    }
    if (character.atLocation == locationId) {
      throw GameRuleException('Esse personagem já está nesse local.');
    }
    _pay(where.moveCost ?? 0);
    character.atLocation = locationId;
    _log('${who.fullName} se move para ${where.fullName}.');
  }

  void boost(int instanceId) {
    _ensureMain();
    final played = _must(instanceId);
    if (seatOf(instanceId) != active) {
      throw GameRuleException('Só as suas cartas usam Boost.');
    }
    final current = card(played.cardId);
    final cost = current.keywordNumber('Boost');
    if (cost == null) throw GameRuleException('Essa carta não tem Boost.');
    if (played.boostUsed) {
      throw GameRuleException('Boost já foi usado neste turno.');
    }
    if (player.deck.isEmpty) throw GameRuleException('O deck está vazio.');
    _pay(cost);
    played.facedown.add(player.deck.removeAt(0));
    played.boostUsed = true;
    _log('${current.fullName} usa Boost $cost.');
  }

  void activate(int instanceId, int abilityIndex) {
    _ensureMain();
    final played = _must(instanceId);
    if (seatOf(instanceId) != active) {
      throw GameRuleException('Só o jogador ativo usa habilidade.');
    }
    final current = card(played.cardId);
    if (abilityIndex < 0 || abilityIndex >= current.abilities.length) {
      throw GameRuleException('Essa habilidade não existe.');
    }
    final ability = current.abilities[abilityIndex];
    if (ability.type != 'activated') {
      throw GameRuleException('Essa habilidade não é ativada.');
    }
    if (!ability.automatedCost) {
      throw GameRuleException(
        'O custo dessa habilidade não é só tinta ou exercer. Resolva no menu da mesa.',
      );
    }
    if (ability.exertCost) {
      if (played.exerted) {
        throw GameRuleException('Essa carta já está exercida.');
      }
      if (current.kind == CardKind.character && played.drying) {
        throw GameRuleException(
          'Personagem secando não se exerce para pagar custo.',
        );
      }
      played.exerted = true;
    }
    _pay(ability.inkCost);
    _log('${current.fullName}: ${ability.name}.');
    effectQueue.addAll(scriptFromTexts([ability.text]));
    _pump();
  }

  void answerEffect(int? targetId, {int? amount}) {
    final current = choice;
    final effect = current?.effect;
    if (current?.kind != ChoiceKind.effect || effect == null) {
      throw GameRuleException('Não há efeito esperando alvo.');
    }
    if (targetId == null) {
      if (!effect.optional && current!.targets.isNotEmpty) {
        throw GameRuleException('Escolha um alvo.');
      }
      choice = null;
      _log('Efeito sem alvo: ${effect.raw}');
      _pump();
      return;
    }
    if (!current!.targets.contains(targetId)) {
      throw GameRuleException('Alvo inválido.');
    }
    final played = _must(targetId);
    final value = amount ?? effect.amount;
    switch (effect.op) {
      case ScriptOp.damage:
        _deal(played, value);
        _sweep();
      case ScriptOp.heal:
        played.damage = max(0, played.damage - value);
      case ScriptOp.banish:
        _banish(played.instanceId);
      case ScriptOp.exert:
        played.exerted = true;
      case ScriptOp.ready:
        played.exerted = false;
      case ScriptOp.draw:
      case ScriptOp.lore:
      case ScriptOp.inkTop:
      case ScriptOp.notice:
        break;
    }
    _log(effect.raw);
    choice = null;
    if (!over) _pump();
  }

  void acknowledge() {
    if (choice?.kind != ChoiceKind.notice) {
      throw GameRuleException('Não há texto esperando confirmação.');
    }
    choice = null;
    _pump();
  }

  void manualDamage(int instanceId, int amount) {
    _ensureManual();
    if (amount <= 0) throw GameRuleException('O dano precisa ser positivo.');
    final played = _must(instanceId);
    _deal(played, amount);
    _sweep();
    _log('Dano aplicado em ${card(played.cardId).fullName}: $amount.');
  }

  void manualHeal(int instanceId, int amount) {
    _ensureManual();
    if (amount <= 0) return;
    final played = _must(instanceId);
    played.damage = max(0, played.damage - amount);
    _log('Dano removido de ${card(played.cardId).fullName}: $amount.');
  }

  void manualBanish(int instanceId) {
    _ensureManual();
    _banish(instanceId);
  }

  void manualDraw(int seat) {
    _ensureManual();
    final drawn = _drawCards(players[seat], 1);
    _log(
      drawn == 0
          ? '${players[seat].name} não compra: o deck está vazio.'
          : '${players[seat].name} compra 1.',
    );
  }

  void manualLore(int seat, int amount) {
    _ensureManual();
    _gainLore(seat, amount);
    _log('${players[seat].name} ganha $amount de lore.');
  }

  void manualExert(int instanceId, bool exerted) {
    _ensureManual();
    _must(instanceId).exerted = exerted;
  }

  void moveDiscard(int seat, int index, int delta) {
    if (seat != active || phase != Phase.main || over) {
      throw GameRuleException('O descarte se reordena no seu turno.');
    }
    final discard = players[seat].discard;
    final next = index + delta;
    if (index < 0 ||
        next < 0 ||
        index >= discard.length ||
        next >= discard.length) {
      return;
    }
    final id = discard.removeAt(index);
    discard.insert(next, id);
  }

  void concede(int seat) {
    if (over) return;
    _lose(seat, '${players[seat].name} desiste.');
  }

  String? endTurnBlockReason() {
    if (over) return 'A partida acabou.';
    if (phase != Phase.main) return 'Ainda não é a fase principal.';
    if (choice != null || effectQueue.isNotEmpty) {
      return 'Resolva a habilidade em andamento.';
    }
    for (final played in player.play) {
      final current = card(played.cardId);
      if (current.kind != CardKind.character || played.exerted) continue;
      if (current.hasKeyword('Reckless') &&
          legalChallengeTargets(played.instanceId).isNotEmpty) {
        return '${current.fullName} é Reckless e ainda pode desafiar.';
      }
      if (current.hasKeyword('Adventurous') &&
          !current.hasKeyword('Reckless') &&
          canQuest(played.instanceId)) {
        return '${current.fullName} é Adventurous e ainda pode explorar.';
      }
    }
    return null;
  }

  void endTurn() {
    final block = endTurnBlockReason();
    if (block != null) throw GameRuleException(block);
    if (player.deck.isEmpty) {
      _lose(active, '${player.name} termina o turno com o deck vazio e perde.');
      return;
    }
    _log('${player.name} encerra o turno.');
    active = 1 - active;
    if (active == 0) turn += 1;
    _beginTurn();
  }

  bool canQuest(int instanceId) {
    if (over || phase != Phase.main || choice != null) return false;
    final played = findPlayed(instanceId);
    if (played == null || seatOf(instanceId) != active) return false;
    final current = card(played.cardId);
    if (current.kind != CardKind.character) return false;
    if (played.exerted || played.drying) return false;
    if (current.hasKeyword('Reckless')) return false;
    return true;
  }

  List<int> legalChallengeTargets(int attackerId) {
    if (over || phase != Phase.main || choice != null) return const [];
    final attacker = findPlayed(attackerId);
    if (attacker == null || seatOf(attackerId) != active || attacker.exerted) {
      return const [];
    }
    final atk = card(attacker.cardId);
    if (atk.kind != CardKind.character || atk.hasKeyword('Adventurous')) {
      return const [];
    }
    if (attacker.drying && !atk.hasKeyword('Rush')) return const [];
    final opponent = players[1 - active];
    final bodyguards = <int>[];
    final characters = <int>[];
    final locations = <int>[];
    for (final played in opponent.play) {
      final current = card(played.cardId);
      if (_evasiveBlocks(atk, current)) continue;
      if (current.kind == CardKind.location) {
        locations.add(played.instanceId);
        continue;
      }
      if (current.kind != CardKind.character || !played.exerted) continue;
      if (current.hasKeyword('Bodyguard')) {
        bodyguards.add(played.instanceId);
      } else {
        characters.add(played.instanceId);
      }
    }
    if (bodyguards.isEmpty) return [...characters, ...locations];
    return [...bodyguards, ...locations];
  }

  List<int> legalShiftTargets(LorcanaCard entering) {
    final cost = entering.keywordNumber('Shift');
    if (entering.kind != CardKind.character || cost == null) return const [];
    return player.play
        .where((played) {
          final current = card(played.cardId);
          return current.kind == CardKind.character &&
              entering.sharesName(current);
        })
        .map((played) => played.instanceId)
        .toList();
  }

  List<int> legalSingers(LorcanaCard song) {
    if (!song.isSong) return const [];
    return player.play.where((played) {
      final current = card(played.cardId);
      if (current.kind != CardKind.character) return false;
      if (played.exerted || played.drying) return false;
      final value = current.keywordNumber('Singer') ?? current.cost;
      return value >= song.cost;
    }).map((played) => played.instanceId).toList();
  }

  PlayedCard spawn(
    int seat,
    int cardId, {
    bool exerted = false,
    bool drying = false,
    int damage = 0,
  }) {
    final played = PlayedCard(
      instanceId: _next++,
      cardId: cardId,
      exerted: exerted,
      drying: drying,
      damage: damage,
    );
    players[seat].play.add(played);
    return played;
  }

  void addInk(int seat, int amount) {
    for (var i = 0; i < amount; i++) {
      players[seat].inkwell.add(InkSlot(0));
    }
  }

  void skipToMain() {
    choice = null;
    phase = Phase.main;
    skipFirstDraw = false;
  }

  void _beginTurn() {
    phase = Phase.ready;
    _ready();
    if (over) return;
    phase = Phase.set;
    _set();
    if (over) return;
    phase = Phase.draw;
    _drawStep();
    if (over) return;
    phase = Phase.main;
    _log('Fase principal — ${player.name}.');
  }

  void _ready() {
    for (final played in player.play) {
      played.exerted = false;
      played.strengthBonus = 0;
      played.boostUsed = false;
    }
    for (final ink in player.inkwell) {
      ink.exerted = false;
    }
    player.inkedThisTurn = false;
    _log('${player.name}: preparar.');
  }

  void _set() {
    for (final played in player.play) {
      final current = card(played.cardId);
      if (current.kind == CardKind.character) played.drying = false;
      if (current.kind == CardKind.location && !over) {
        _gainLore(active, max(0, current.lore ?? 0));
      }
    }
    _log('${player.name}: definir.');
  }

  void _drawStep() {
    if (skipFirstDraw) {
      skipFirstDraw = false;
      _log('${player.name} pula a compra do primeiro turno.');
      return;
    }
    final drawn = _drawCards(player, 1);
    _log(
      drawn == 0
          ? '${player.name} não compra: o deck está vazio.'
          : '${player.name} compra 1 carta.',
    );
  }

  int _drawCards(PlayerBoard board, int count) {
    var drawn = 0;
    while (drawn < count && board.deck.isNotEmpty) {
      board.hand.add(board.deck.removeAt(0));
      drawn++;
    }
    return drawn;
  }

  void _pay(int amount) {
    if (amount < 0) throw GameRuleException('Custo inválido.');
    if (player.readyInk < amount) {
      throw GameRuleException(
        'Tinta pronta insuficiente (${player.readyInk} de $amount).',
      );
    }
    var left = amount;
    for (final ink in player.inkwell) {
      if (left == 0) break;
      if (!ink.exerted) {
        ink.exerted = true;
        left--;
      }
    }
  }

  void _validateShift(LorcanaCard entering, int onto) {
    if (entering.keywordNumber('Shift') == null) {
      throw GameRuleException('Esse Shift não é pago só com tinta.');
    }
    if (seatOf(onto) != active || !legalShiftTargets(entering).contains(onto)) {
      throw GameRuleException('Não há personagem com esse nome para o Shift.');
    }
  }

  void _validateSinger(LorcanaCard song, int singer) {
    if (!legalSingers(song).contains(singer)) {
      throw GameRuleException('Esse personagem não pode cantar esta canção.');
    }
  }

  void _noteTriggers(LorcanaCard entering) {
    final texts = entering.abilities
        .where((ability) => ability.type == 'triggered' && ability.text.isNotEmpty)
        .map((ability) => ability.text)
        .toList();
    if (texts.isEmpty) return;
    _log('Disparada ainda manual: ${texts.first}');
  }

  void _pump() {
    while (effectQueue.isNotEmpty && !over && choice == null) {
      final effect = effectQueue.removeAt(0);
      if (effect.op == ScriptOp.notice) {
        choice = Choice(
          kind: ChoiceKind.notice,
          seat: active,
          effect: effect,
          prompt: effect.raw,
        );
        return;
      }
      if (effect.op == ScriptOp.draw) {
        final drawn = _drawCards(player, effect.amount);
        _log('${player.name} compra $drawn.');
        continue;
      }
      if (effect.op == ScriptOp.lore) {
        _gainLore(active, effect.amount);
        _log(effect.raw);
        continue;
      }
      if (effect.op == ScriptOp.inkTop) {
        _inkTop();
        continue;
      }
      final targets = _targetsFor(effect);
      if (targets.isEmpty) {
        _log('Sem alvo: ${effect.raw}');
        continue;
      }
      choice = Choice(
        kind: ChoiceKind.effect,
        seat: active,
        effect: effect,
        targets: targets,
        prompt: effect.raw,
      );
      return;
    }
  }

  List<int> _targetsFor(ScriptedEffect effect) {
    final ids = <int>[];
    for (var seat = 0; seat < players.length; seat++) {
      if (effect.opposingOnly && seat == active) continue;
      for (final played in players[seat].play) {
        final current = card(played.cardId);
        final character = current.kind == CardKind.character;
        final location = current.kind == CardKind.location;
        if (effect.characterOnly && !character) continue;
        if (effect.locationOnly && !location) continue;
        if (!character && !location) continue;
        ids.add(played.instanceId);
      }
    }
    return ids;
  }

  void _inkTop() {
    if (player.deck.isEmpty) {
      _log('Sem carta no deck para o tinteiro.');
      return;
    }
    final id = player.deck.removeAt(0);
    player.inkwell.add(InkSlot(id, exerted: true));
    _log('${player.name} põe o topo do deck no tinteiro, exercido.');
  }

  int _strength(PlayedCard played, {required bool challenging}) {
    final current = card(played.cardId);
    var value = (current.strength ?? 0) + played.strengthBonus;
    if (challenging) value += current.keywordNumber('Challenger') ?? 0;
    return max(0, value);
  }

  void _deal(PlayedCard target, int amount) {
    final resist = card(target.cardId).keywordNumber('Resist') ?? 0;
    final dealt = amount - resist;
    if (dealt <= 0) return;
    target.damage += dealt;
  }

  bool _evasiveBlocks(LorcanaCard attacker, LorcanaCard defender) {
    if (!defender.hasKeyword('Evasive')) return false;
    return !attacker.hasKeyword('Evasive') && !attacker.hasKeyword('Alert');
  }

  void _sweep() {
    final dead = <int>[];
    for (final board in players) {
      for (final played in board.play) {
        final current = card(played.cardId);
        if (current.kind != CardKind.character &&
            current.kind != CardKind.location) {
          continue;
        }
        if (played.damage >= (current.willpower ?? 0)) dead.add(played.instanceId);
      }
    }
    for (final id in dead) {
      _banish(id);
    }
  }

  void _banish(int instanceId) {
    for (final board in players) {
      final index = board.play.indexWhere(
        (played) => played.instanceId == instanceId,
      );
      if (index < 0) continue;
      final played = board.play.removeAt(index);
      board.discard.add(played.cardId);
      board.discard.addAll(played.under);
      board.discard.addAll(played.facedown);
      for (final other in players) {
        for (final remaining in other.play) {
          if (remaining.atLocation == instanceId) remaining.atLocation = null;
        }
      }
      _log('${card(played.cardId).fullName} é banido.');
      return;
    }
  }

  void _gainLore(int seat, int amount) {
    if (amount <= 0 || over) return;
    players[seat].lore += amount;
    if (players[seat].lore >= 20) {
      winnerSeat = seat;
      choice = null;
      effectQueue.clear();
      _log('${players[seat].name} chega a ${players[seat].lore} de lore e vence.');
    }
  }

  void _lose(int seat, String reason) {
    winnerSeat = 1 - seat;
    choice = null;
    effectQueue.clear();
    _log(reason);
  }

  void _ensureMain() {
    if (over) throw GameRuleException('A partida acabou.');
    if (phase != Phase.main || choice != null) {
      throw GameRuleException('Resolva a etapa atual antes dessa ação.');
    }
  }

  void _ensureManual() {
    if (over) throw GameRuleException('A partida acabou.');
    if (phase != Phase.main) {
      throw GameRuleException('A mesa só se ajusta na fase principal.');
    }
    final kind = choice?.kind;
    if (kind != null && kind != ChoiceKind.notice && kind != ChoiceKind.effect) {
      throw GameRuleException('Termine a escolha atual.');
    }
  }

  int _handCard(PlayerBoard board, int handIndex) {
    if (handIndex < 0 || handIndex >= board.hand.length) {
      throw GameRuleException('Essa carta não está na mão.');
    }
    return board.hand[handIndex];
  }

  PlayedCard _must(int instanceId) {
    final played = findPlayed(instanceId);
    if (played == null) {
      throw GameRuleException('Essa carta não está em jogo.');
    }
    return played;
  }

  void _log(String line) {
    log.add(line);
    if (log.length > 400) log.removeRange(0, log.length - 400);
  }
}
