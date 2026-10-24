import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../services/deck_store.dart';
import '../deck/deck_editor_screen.dart';
import '../deck/deck_rules.dart';
import '../match/match_screen.dart';
import '../match/match_table.dart';
import 'practice_deck.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key, required this.hotseat});

  final bool hotseat;

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  List<SavedDeck> _decks = [];
  PlayFormat _format = PlayFormat.casual;
  String? _first;
  String? _second;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scope = LorcanaScope.of(context);
    final decks = await scope.decks.loadAll();
    final format = await scope.settings.format();
    final first = await scope.settings.deckPath(0);
    final second = await scope.settings.deckPath(1);
    if (!mounted) return;
    setState(() {
      _decks = decks;
      _format = format;
      _first = _match(decks, first);
      _second = _match(decks, second);
      _loading = false;
    });
  }

  String? _match(List<SavedDeck> decks, String? path) {
    for (final deck in decks) {
      if (deck.file.path == path) return path;
    }
    return decks.isEmpty ? null : decks.first.file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hotseat ? 'Partida local' : 'Praticar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    DropdownButtonFormField<PlayFormat>(
                      initialValue: _format,
                      decoration: const InputDecoration(labelText: 'Modalidade'),
                      items: [
                        for (final format in PlayFormat.values)
                          DropdownMenuItem(
                            value: format,
                            child: Text(format.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _format = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_decks.isEmpty)
                      const Text('Ainda não há deck salvo. Monte um no editor.')
                    else ...[
                      _deckField('Seu deck', _first, (value) => _first = value),
                      const SizedBox(height: 16),
                      if (widget.hotseat)
                        _deckField(
                          'Deck do outro jogador',
                          _second,
                          (value) => _second = value,
                        )
                      else
                        const ListTile(
                          title: Text('Oponente'),
                          subtitle: Text(
                            'Um deck de treino de 60 cartas, em duas tintas, jogado pela mesa.',
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _decks.isEmpty ? null : _start,
                      child: const Text('Começar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DeckEditorScreen(),
                          ),
                        );
                        await _load();
                      },
                      child: const Text('Abrir o editor'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _deckField(String label, String? selected, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final deck in _decks)
          DropdownMenuItem(
            value: deck.file.path,
            child: Text('${deck.name} (${deck.ids.length})'),
          ),
      ],
      onChanged: (value) => setState(() => onChanged(value)),
    );
  }

  Future<void> _start() async {
    final scope = LorcanaScope.of(context);
    final first = _find(_first);
    if (first == null) return;
    final issues = DeckRules.issues(
      first.ids,
      scope.catalog.byId,
      format: _format,
    );
    final secondIds = <int>[];
    var secondName = 'Treino';
    if (widget.hotseat) {
      final second = _find(_second);
      if (second == null) return;
      issues.addAll(
        DeckRules.issues(second.ids, scope.catalog.byId, format: _format),
      );
      secondIds.addAll(second.ids);
      secondName = second.name;
    } else {
      final practice = PracticeDeck.build(scope.catalog.cards, Random());
      secondIds.addAll(practice.ids);
      secondName = practice.name;
      if (secondIds.isEmpty) {
        issues.add('Não há cartas suficientes para montar o treino.');
      }
    }
    if (issues.isNotEmpty) {
      _show(issues.take(6).join('\n'));
      return;
    }
    await scope.settings.saveFormat(_format);
    await scope.settings.saveDeckPath(0, first.file.path);
    if (widget.hotseat) await scope.settings.saveDeckPath(1, _second);
    if (!mounted) return;
    final table = MatchTable.start(
      deckA: first.ids,
      deckB: secondIds,
      catalog: scope.catalog.byId,
      nameA: first.name,
      nameB: secondName,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(table: table, hotseat: widget.hotseat),
      ),
    );
  }

  SavedDeck? _find(String? path) {
    for (final deck in _decks) {
      if (deck.file.path == path) return deck;
    }
    return null;
  }

  void _show(String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deck fora da modalidade'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
