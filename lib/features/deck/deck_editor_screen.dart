import 'dart:math';

import 'package:flutter/material.dart' hide Ink;

import '../../app_scope.dart';
import '../../services/deck_store.dart';
import '../../widgets/card_chip.dart';
import '../../widgets/ink_style.dart';
import '../cards/card_detail_dialog.dart';
import '../cards/lorcana_card.dart';
import '../practice/practice_deck.dart';
import 'deck_rules.dart';

class DeckEditorScreen extends StatefulWidget {
  const DeckEditorScreen({super.key, this.existing});

  final SavedDeck? existing;

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  final _search = TextEditingController();
  final _name = TextEditingController(text: 'Meu deck');
  final List<int> _ids = [];
  Ink? _ink;
  CardKind? _kind;
  int? _cost;
  int _limit = 80;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _ids.addAll(existing.ids);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = LorcanaScope.of(context).catalog;
    final cards = _filtered(catalog.cards);
    final visible = cards.take(_limit).toList();
    final issues = DeckRules.issues(
      _ids,
      catalog.byId,
      format: PlayFormat.core,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar deck'),
        actions: [
          TextButton(onPressed: _fillPractice, child: const Text('Montar treino')),
          TextButton(onPressed: _save, child: const Text('Salvar')),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Nome, várias palavras',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() => _limit = 80),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final ink in Ink.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(inkLabel(ink)),
                            selected: _ink == ink,
                            onSelected: (selected) => setState(() {
                              _ink = selected ? ink : null;
                              _limit = 80;
                            }),
                          ),
                        ),
                      for (final kind in CardKind.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(kindLabel(kind)),
                            selected: _kind == kind,
                            onSelected: (selected) => setState(() {
                              _kind = selected ? kind : null;
                              _limit = 80;
                            }),
                          ),
                        ),
                      DropdownButton<int?>(
                        value: _cost,
                        hint: const Text('Custo'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Custo')),
                          for (var cost = 0; cost <= 10; cost++)
                            DropdownMenuItem(value: cost, child: Text('$cost')),
                        ],
                        onChanged: (value) => setState(() {
                          _cost = value;
                          _limit = 80;
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisExtent: 210,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final card = visible[index];
                      return InkWell(
                        onTap: () => _add(card),
                        onLongPress: () => showCardDetail(context, card),
                        child: Column(
                          children: [
                            CardChip(card: card, width: 110),
                            Text(
                              card.fullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (cards.length > visible.length)
                  TextButton(
                    onPressed: () => setState(() => _limit += 80),
                    child: Text('Mostrar mais (${visible.length} de ${cards.length})'),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome do deck'),
                  ),
                ),
                Text('${_ids.length} cartas'),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _summary(catalog.byId),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (issues.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      issues.take(4).join('\n'),
                      style: const TextStyle(color: Color(0xFFE7B3B3)),
                    ),
                  )
                else
                  const Text('Legal no Core, no Infinity e no casual.'),
                Expanded(
                  child: ListView(
                    children: [
                      for (final line in _lines(catalog.byId))
                        ListTile(
                          dense: true,
                          title: Text(line.card.fullName),
                          subtitle: Text(
                            '${line.card.cost} · ${line.card.inks.map(inkLabel).join('/')}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${line.count}'),
                              IconButton(
                                onPressed: () => _remove(line.card.id),
                                icon: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                          onTap: () => showCardDetail(context, line.card),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<LorcanaCard> _filtered(List<LorcanaCard> cards) {
    final words = _search.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return cards.where((card) {
      if (_ink != null && !card.inks.contains(_ink)) return false;
      if (_kind != null && card.kind != _kind) return false;
      if (_cost != null && card.cost != _cost) return false;
      return words.every((word) => card.simpleName.contains(word));
    }).toList();
  }

  void _add(LorcanaCard card) {
    final count = _ids.where((id) {
      final other = LorcanaScope.of(context).catalog.byId[id];
      return other?.fullName == card.fullName;
    }).length;
    final limit = card.maxInDeck ?? 99;
    if (count >= limit) {
      _message('O máximo de ${card.fullName} é $limit.');
      return;
    }
    setState(() => _ids.add(card.id));
  }

  void _remove(int id) {
    setState(() => _ids.remove(id));
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? 'Meu deck' : _name.text.trim();
    final saved = await LorcanaScope.of(context).decks.save(name, _ids);
    if (!mounted) return;
    _message('Salvo em ${saved.file.path}');
  }

  void _fillPractice() {
    final catalog = LorcanaScope.of(context).catalog;
    final deck = PracticeDeck.build(catalog.cards, Random());
    setState(() {
      _ids
        ..clear()
        ..addAll(deck.ids);
      _name.text = deck.name;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _summary(Map<int, LorcanaCard> cards) {
    final counts = <Ink, int>{};
    for (final id in _ids) {
      final card = cards[id];
      if (card == null) continue;
      for (final ink in card.inks) {
        counts[ink] = (counts[ink] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return 'Nenhuma tinta.';
    return counts.entries.map((entry) => '${inkLabel(entry.key)} ${entry.value}').join(' · ');
  }

  List<_Line> _lines(Map<int, LorcanaCard> cards) {
    final grouped = <int, int>{};
    for (final id in _ids) {
      grouped[id] = (grouped[id] ?? 0) + 1;
    }
    final lines = <_Line>[];
    for (final entry in grouped.entries) {
      final card = cards[entry.key];
      if (card == null) continue;
      lines.add(_Line(card, entry.value));
    }
    lines.sort((a, b) {
      final byCost = a.card.cost.compareTo(b.card.cost);
      if (byCost != 0) return byCost;
      return a.card.fullName.compareTo(b.card.fullName);
    });
    return lines;
  }
}

class _Line {
  const _Line(this.card, this.count);

  final LorcanaCard card;
  final int count;
}
