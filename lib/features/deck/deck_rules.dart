import '../cards/lorcana_card.dart';

enum PlayFormat { casual, core, infinity }

extension PlayFormatLabel on PlayFormat {
  String get label => switch (this) {
    PlayFormat.casual => 'Casual',
    PlayFormat.core => 'Core',
    PlayFormat.infinity => 'Infinity',
  };
}

class DeckRules {
  const DeckRules._();

  static List<String> issues(
    List<int> ids,
    Map<int, LorcanaCard> cards, {
    required PlayFormat format,
  }) {
    if (ids.isEmpty) return const ['O deck está vazio.'];
    final found = <LorcanaCard>[];
    final messages = <String>[];
    for (final id in ids) {
      final card = cards[id];
      if (card == null) {
        messages.add('A carta $id não está na base.');
        continue;
      }
      found.add(card);
    }
    if (format == PlayFormat.casual) return messages;

    if (found.length < 60) {
      messages.add('O construído pede 60 cartas. Este deck tem ${found.length}.');
    }
    final inks = <Ink>{};
    for (final card in found) {
      if (card.inks.isEmpty) {
        messages.add('${card.fullName} não tem tinta e não entra no construído.');
      }
      inks.addAll(card.inks);
      if (format == PlayFormat.core && !card.coreLegal) {
        messages.add('${card.fullName} não está legal no Core.');
      }
      if (format == PlayFormat.infinity && !card.infinityLegal) {
        messages.add('${card.fullName} não está legal no Infinity.');
      }
    }
    if (inks.length > 2) {
      messages.add('O deck usa ${inks.length} tintas. O máximo é duas.');
    }

    final groups = <String, List<LorcanaCard>>{};
    for (final card in found) {
      groups.putIfAbsent(card.fullName, () => []).add(card);
    }
    for (final entry in groups.entries) {
      final limit = _limit(entry.value);
      if (limit != null && entry.value.length > limit) {
        messages.add(
          '${entry.key} tem ${entry.value.length} cópias. O máximo é $limit.',
        );
      }
    }
    return messages;
  }

  static int? _limit(List<LorcanaCard> group) {
    if (group.any((card) => card.unlimitedCopies)) return null;
    var limit = 4;
    for (final card in group) {
      final value = card.copyLimit ?? 4;
      if (value > limit) limit = value;
    }
    return limit;
  }
}
