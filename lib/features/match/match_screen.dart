import 'package:flutter/material.dart';

import '../../widgets/card_chip.dart';
import '../cards/card_detail_dialog.dart';
import '../cards/lorcana_card.dart';
import '../practice/practice_ai.dart';
import 'match_table.dart';

enum _Pick { none, challenge, singer, shift, move }

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.table, required this.hotseat});

  final MatchTable table;
  final bool hotseat;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _ai = PracticeAi();
  int? _hand;
  int? _instance;
  _Pick _pick = _Pick.none;
  final Set<int> _mulligan = {};
  bool _aiRunning = false;
  int _shownSeat = 0;
  int _seenActive = 0;
  int _seenTurn = 1;

  MatchTable get table => widget.table;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAi());
  }

  int get _focusSeat {
    final choice = table.choice;
    if (choice?.kind == ChoiceKind.mulligan) return choice!.seat;
    return table.active;
  }

  bool get _covered => widget.hotseat && _shownSeat != _focusSeat;

  @override
  Widget build(BuildContext context) {
    final viewer = widget.hotseat ? _focusSeat : 0;
    final rival = 1 - viewer;
    return PopScope(
      canPop: table.over,
      onPopInvokedWithResult: (didPop, result) => _confirmLeave(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            table.over
                ? '${table.players[table.winnerSeat!].name} vence'
                : 'Turno ${table.turn} · ${table.players[table.active].name}',
          ),
          actions: [
            TextButton(
              onPressed: () => _act(() => table.concede(viewer)),
              child: const Text('Desistir'),
            ),
          ],
        ),
        body: _covered
            ? Center(
                child: FilledButton(
                  onPressed: () => setState(() => _shownSeat = _focusSeat),
                  child: Text('Passe para ${table.players[_focusSeat].name} e revele a mão'),
                ),
              )
            : Column(
                children: [
                  _strip(rival),
                  _field(rival, mine: false),
                  _handRow(rival, reveal: false),
                  _logBar(),
                  if (table.choice != null) _choiceBanner(),
                  _field(viewer, mine: true),
                  _strip(viewer),
                  Expanded(child: _handRow(viewer, reveal: true)),
                  _actions(viewer),
                ],
              ),
      ),
    );
  }

  Widget _strip(int seat) {
    final board = table.players[seat];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(board.name)),
          Text('Lore ${board.lore}'),
          const SizedBox(width: 12),
          Text('Tinta ${board.readyInk}/${board.inkwell.length}'),
          const SizedBox(width: 12),
          Text('Deck ${board.deck.length}'),
          TextButton(
            onPressed: () => _discard(seat),
            child: Text('Descarte ${board.discard.length}'),
          ),
        ],
      ),
    );
  }

  Widget _field(int seat, {required bool mine}) {
    final play = table.players[seat].play;
    return SizedBox(
      height: 168,
      child: play.isEmpty
          ? const Center(child: Text('Mesa vazia'))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: play.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final played = play[index];
                final card = table.card(played.cardId);
                final where = played.atLocation == null
                    ? null
                    : table.card(table.findPlayed(played.atLocation!)!.cardId).name;
                return Center(
                  child: CardChip(
                    card: card,
                    exerted: played.exerted,
                    drying: played.drying,
                    damage: played.damage,
                    selected: _instance == played.instanceId,
                    caption: where,
                    onTap: () => _tapInstance(played.instanceId, mine: mine),
                    onLongPress: () => showCardDetail(context, card),
                  ),
                );
              },
            ),
    );
  }

  Widget _handRow(int seat, {required bool reveal}) {
    final hand = table.players[seat].hand;
    return SizedBox(
      height: reveal ? 180 : 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: hand.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (!reveal) return const CardChip(card: null, width: 58);
          final card = table.card(hand[index]);
          final marked = table.choice?.kind == ChoiceKind.mulligan && _mulligan.contains(index);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CardChip(
                  card: card,
                  width: 96,
                  selected: _hand == index || marked,
                  onTap: () => _tapHand(index),
                  onLongPress: () => showCardDetail(context, card),
                ),
                if (marked) const Text('fundo', style: TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _logBar() {
    final line = table.log.isEmpty ? 'Partida iniciada.' : table.log.last;
    return Material(
      color: const Color(0xFF1B2030),
      child: InkWell(
        onTap: _showLog,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis)),
              TextButton(onPressed: _manual, child: const Text('Resolver efeito')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceBanner() {
    final choice = table.choice!;
    return Container(
      width: double.infinity,
      color: const Color(0xFF2A2418),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(choice.prompt, maxLines: 4, overflow: TextOverflow.ellipsis),
          Wrap(
            spacing: 8,
            children: [
              if (choice.kind == ChoiceKind.mulligan)
                FilledButton(
                  onPressed: () => _act(() {
                    table.mulligan(choice.seat, _mulligan.toList());
                    _mulligan.clear();
                  }),
                  child: const Text('Confirmar mão'),
                ),
              if (choice.kind == ChoiceKind.bodyguard) ...[
                FilledButton(
                  onPressed: () => _act(() => table.answerBodyguard(false)),
                  child: const Text('Entrar pronta'),
                ),
                FilledButton(
                  onPressed: () => _act(() => table.answerBodyguard(true)),
                  child: const Text('Entrar exercida'),
                ),
                TextButton(
                  onPressed: () => _act(table.cancelBodyguard),
                  child: const Text('Cancelar'),
                ),
              ],
              if (choice.kind == ChoiceKind.support)
                TextButton(
                  onPressed: () => _act(() => table.answerSupport(null)),
                  child: const Text('Não apoiar'),
                ),
              if (choice.kind == ChoiceKind.effect && choice.effect!.optional)
                TextButton(
                  onPressed: () => _act(() => table.answerEffect(null)),
                  child: const Text('Não aplicar'),
                ),
              if (choice.kind == ChoiceKind.notice)
                FilledButton(
                  onPressed: () => _act(table.acknowledge),
                  child: const Text('Continuar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions(int viewer) {
    final mine = viewer == table.active && table.phase == Phase.main && table.choice == null && !table.over;
    final board = table.players[viewer];
    final handCard = _hand != null && _hand! < board.hand.length
        ? table.card(board.hand[_hand!])
        : null;
    final played = _instance == null ? null : table.findPlayed(_instance!);
    final block = table.endTurnBlockReason();
    return Material(
      color: const Color(0xFF161A24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (handCard != null && mine && handCard.inkwell && !board.inkedThisTurn)
              FilledButton(
                onPressed: () => _act(() => table.ink(_hand!)),
                child: const Text('Tintar'),
              ),
            if (handCard != null && mine && handCard.cost <= board.readyInk)
              FilledButton(
                onPressed: () => _act(() => table.playFromHand(_hand!)),
                child: const Text('Jogar'),
              ),
            if (handCard != null && mine && table.legalSingers(handCard).isNotEmpty)
              FilledButton(
                onPressed: () => setState(() => _pick = _Pick.singer),
                child: const Text('Cantar'),
              ),
            if (handCard != null && mine && table.legalShiftTargets(handCard).isNotEmpty)
              FilledButton(
                onPressed: () => setState(() => _pick = _Pick.shift),
                child: const Text('Shift'),
              ),
            if (played != null && mine && table.canQuest(played.instanceId))
              FilledButton(
                onPressed: () => _act(() => table.quest(played.instanceId)),
                child: const Text('Explorar'),
              ),
            if (played != null && mine && table.legalChallengeTargets(played.instanceId).isNotEmpty)
              FilledButton(
                onPressed: () => setState(() => _pick = _Pick.challenge),
                child: const Text('Desafiar'),
              ),
            if (played != null && mine && table.card(played.cardId).kind == CardKind.character)
              FilledButton(
                onPressed: () => setState(() => _pick = _Pick.move),
                child: const Text('Mover'),
              ),
            if (played != null && mine && table.card(played.cardId).hasKeyword('Boost'))
              FilledButton(
                onPressed: () => _act(() => table.boost(played.instanceId)),
                child: const Text('Boost'),
              ),
            if (played != null && mine)
              for (var index = 0; index < table.card(played.cardId).abilities.length; index++)
                if (table.card(played.cardId).abilities[index].type == 'activated' &&
                    table.card(played.cardId).abilities[index].automatedCost)
                  FilledButton(
                    onPressed: () => _act(() => table.activate(played.instanceId, index)),
                    child: Text(table.card(played.cardId).abilities[index].name),
                  ),
            FilledButton.tonal(
              onPressed: mine ? () => _act(table.endTurn) : null,
              child: const Text('Encerrar turno'),
            ),
            if (block != null && mine)
              Text(block, style: const TextStyle(color: Color(0xFFE7B3B3))),
            if (_pick != _Pick.none)
              TextButton(
                onPressed: () => setState(() => _pick = _Pick.none),
                child: const Text('Cancelar escolha'),
              ),
            if (_aiRunning) const Text('Treino jogando…'),
          ],
        ),
      ),
    );
  }

  void _tapHand(int index) {
    final choice = table.choice;
    if (choice?.kind == ChoiceKind.mulligan && choice!.seat == (widget.hotseat ? _focusSeat : 0)) {
      setState(() {
        if (!_mulligan.add(index)) _mulligan.remove(index);
      });
      return;
    }
    setState(() {
      _hand = index;
      _instance = null;
      _pick = _Pick.none;
    });
  }

  void _tapInstance(int instanceId, {required bool mine}) {
    final choice = table.choice;
    if (choice?.kind == ChoiceKind.effect && choice!.targets.contains(instanceId)) {
      _act(() => table.answerEffect(instanceId));
      return;
    }
    if (choice?.kind == ChoiceKind.support && choice!.targets.contains(instanceId)) {
      _act(() => table.answerSupport(instanceId));
      return;
    }
    if (_pick == _Pick.challenge && _instance != null) {
      _act(() => table.challenge(_instance!, instanceId));
      return;
    }
    if (_pick == _Pick.singer && _hand != null) {
      _act(() => table.playFromHand(_hand!, singer: instanceId));
      return;
    }
    if (_pick == _Pick.shift && _hand != null) {
      _act(() => table.playFromHand(_hand!, shiftOnto: instanceId));
      return;
    }
    if (_pick == _Pick.move && _instance != null && mine) {
      _act(() => table.move(_instance!, instanceId));
      return;
    }
    if (!mine && _pick == _Pick.none) {
      setState(() => _instance = instanceId);
      return;
    }
    if (mine) {
      setState(() {
        _instance = instanceId;
        _hand = null;
      });
    }
  }

  void _act(void Function() action) {
    try {
      action();
      _pick = _Pick.none;
      _hand = null;
      _instance = null;
      if (_seenActive != table.active || _seenTurn != table.turn) {
        _seenActive = table.active;
        _seenTurn = table.turn;
        _hand = null;
        _instance = null;
        _mulligan.clear();
      }
      setState(() {});
      _runAi();
    } on GameRuleException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _runAi() async {
    if (_aiRunning || widget.hotseat || table.over) return;
    _aiRunning = true;
    var steps = 0;
    try {
      while (mounted && _aiShouldAct && steps < 40) {
        steps++;
        final acted = _ai.step(table);
        if (!mounted) return;
        setState(() {});
        if (!acted) {
          if (table.phase == Phase.main && table.choice == null && table.active == 1) {
            table.endTurn();
            if (mounted) setState(() {});
          }
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    } on GameRuleException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _aiRunning = false;
      if (mounted) setState(() {});
    }
  }

  bool get _aiShouldAct {
    if (table.over) return false;
    final choice = table.choice;
    if (choice != null) return choice.seat == 1;
    return table.phase == Phase.main && table.active == 1;
  }

  Future<void> _confirmLeave(bool didPop) async {
    if (didPop || !mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da partida?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ficar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  void _showLog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registro'),
        content: SizedBox(
          width: 480,
          child: ListView(
            children: [for (final line in table.log) Text(line)],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _discard(int seat) async {
    final board = table.players[seat];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Descarte de ${board.name}'),
        content: SizedBox(
          width: 360,
          child: board.discard.isEmpty
              ? const Text('Vazio.')
              : ListView.builder(
                  itemCount: board.discard.length,
                  itemBuilder: (context, index) {
                    final card = table.card(board.discard[index]);
                    return ListTile(
                      title: Text(card.fullName),
                      onTap: () => showCardDetail(context, card),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _manual() async {
    if (!widget.hotseat && table.active != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espere a vez do treino terminar.')),
      );
      return;
    }
    var amount = 1;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            void apply(void Function() action) {
              Navigator.pop(context);
              _act(action);
            }

            return AlertDialog(
              title: const Text('Resolver efeito'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Escolha uma carta na mesa e o valor. Resistir vale no dano.'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => setLocal(() => amount = amount > 1 ? amount - 1 : 1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$amount'),
                      IconButton(
                        onPressed: () => setLocal(() => amount += 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _instance == null
                      ? null
                      : () => apply(() => table.manualDamage(_instance!, amount)),
                  child: const Text('Dano'),
                ),
                TextButton(
                  onPressed: _instance == null
                      ? null
                      : () => apply(() => table.manualHeal(_instance!, amount)),
                  child: const Text('Curar'),
                ),
                TextButton(
                  onPressed: _instance == null
                      ? null
                      : () => apply(() => table.manualBanish(_instance!)),
                  child: const Text('Banir'),
                ),
                TextButton(
                  onPressed: _instance == null
                      ? null
                      : () => apply(() => table.manualExert(_instance!, true)),
                  child: const Text('Exercer'),
                ),
                TextButton(
                  onPressed: _instance == null
                      ? null
                      : () => apply(() => table.manualExert(_instance!, false)),
                  child: const Text('Endireitar'),
                ),
                TextButton(
                  onPressed: () => apply(() => table.manualDraw(table.active)),
                  child: const Text('Comprar'),
                ),
                TextButton(
                  onPressed: () => apply(() => table.manualLore(table.active, amount)),
                  child: const Text('Lore'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
