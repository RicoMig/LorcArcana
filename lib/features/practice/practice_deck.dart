import 'dart:math';

import '../cards/lorcana_card.dart';
import '../../widgets/ink_style.dart';

class PracticeDeck {
  const PracticeDeck({required this.name, required this.ids});

  final String name;
  final List<int> ids;

  static PracticeDeck build(List<LorcanaCard> cards, Random random) {
    final core = cards.where((card) {
      return card.coreLegal && card.inks.isNotEmpty && card.kind != CardKind.action;
    }).toList();
    final source = core.length >= 40
        ? core
        : cards.where((card) {
            return card.infinityLegal &&
                card.inks.isNotEmpty &&
                card.kind != CardKind.action;
          }).toList();
    final counts = <Ink, int>{};
    for (final card in source) {
      for (final ink in card.inks.toSet()) {
        counts[ink] = (counts[ink] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) {
      return const PracticeDeck(name: 'Treino', ids: []);
    }
    final first = ranked.first.key;
    final second = ranked.length > 1 ? ranked[1].key : first;
    final pool = source.where((card) {
      return card.inks.every((ink) => ink == first || ink == second);
    }).toList();
    final byName = <String, LorcanaCard>{};
    for (final card in pool) {
      final current = byName[card.fullName];
      if (current == null || _better(card, current)) byName[card.fullName] = card;
    }
    final groups = byName.values.toList()..shuffle(random);
    groups.sort((a, b) {
      if (a.inkwell != b.inkwell) return a.inkwell ? -1 : 1;
      final byCost = a.cost.compareTo(b.cost);
      if (byCost != 0) return byCost;
      return (b.lore ?? 0).compareTo(a.lore ?? 0);
    });
    final cheap = groups.where((card) => card.cost <= 3).take(12);
    final mid = groups.where((card) => card.cost >= 4 && card.cost <= 6).take(6);
    final chosen = <LorcanaCard>[...cheap, ...mid];
    if (chosen.length < 15) {
      chosen.addAll(
        groups.where((card) => !chosen.contains(card)).take(15 - chosen.length),
      );
    }
    final ids = <int>[];
    for (final card in chosen) {
      final copies = min(4, card.maxInDeck ?? 4);
      for (var copy = 0; copy < copies && ids.length < 60; copy++) {
        ids.add(card.id);
      }
    }
    final inkName = first == second
        ? inkLabel(first)
        : '${inkLabel(first)}/${inkLabel(second)}';
    return PracticeDeck(name: 'Treino $inkName', ids: ids);
  }

  static bool _better(LorcanaCard next, LorcanaCard current) {
    if (next.inkwell != current.inkwell) return next.inkwell;
    return next.cost < current.cost;
  }
}
