enum ScriptOp { damage, heal, draw, lore, banish, exert, ready, inkTop, notice }

class ScriptedEffect {
  const ScriptedEffect({
    required this.op,
    required this.raw,
    this.amount = 0,
    this.opposingOnly = false,
    this.characterOnly = false,
    this.locationOnly = false,
    this.optional = false,
  });

  final ScriptOp op;
  final String raw;
  final int amount;
  final bool opposingOnly;
  final bool characterOnly;
  final bool locationOnly;
  final bool optional;

  bool get needsTarget =>
      op == ScriptOp.damage ||
      op == ScriptOp.heal ||
      op == ScriptOp.banish ||
      op == ScriptOp.exert ||
      op == ScriptOp.ready;

  factory ScriptedEffect.notice(String raw) {
    return ScriptedEffect(op: ScriptOp.notice, raw: raw);
  }
}

List<ScriptedEffect> scriptFromTexts(List<String> chunks) {
  final effects = <ScriptedEffect>[];
  for (final chunk in chunks) {
    final flat = chunk.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) continue;
    final sentences = flat.split(RegExp(r'(?<=[.!])\s+'));
    final parsed = <ScriptedEffect>[];
    final unknown = <String>[];
    for (final sentence in sentences) {
      final text = sentence.trim();
      if (text.isEmpty) continue;
      final effect = _parseSentence(text);
      if (effect == null) {
        unknown.add(text);
      } else {
        parsed.add(effect);
      }
    }
    if (unknown.isEmpty) {
      effects.addAll(parsed);
    } else if (parsed.isEmpty) {
      effects.add(ScriptedEffect.notice(flat));
    } else {
      effects.addAll(parsed);
      effects.add(ScriptedEffect.notice(unknown.join(' ')));
    }
  }
  return effects;
}

ScriptedEffect? _parseSentence(String sentence) {
  final text = sentence.endsWith('.')
      ? sentence.substring(0, sentence.length - 1).trim()
      : sentence;
  final deal = RegExp(
    r'^Deal (\d+) damage to chosen (.+)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (deal != null) {
    final who = deal.group(2)!.toLowerCase();
    if (who.contains('damaged') || who.contains('equal')) return null;
    final character = who.contains('character');
    final location = who.contains('location');
    return ScriptedEffect(
      op: ScriptOp.damage,
      amount: int.parse(deal.group(1)!),
      raw: sentence,
      opposingOnly: who.contains('opposing'),
      characterOnly: character && !location,
      locationOnly: location && !character,
    );
  }
  final heal = RegExp(
    r'^Remove up to (\d+) damage from chosen character$',
    caseSensitive: false,
  ).firstMatch(text);
  if (heal != null) {
    return ScriptedEffect(
      op: ScriptOp.heal,
      amount: int.parse(heal.group(1)!),
      raw: sentence,
      characterOnly: true,
      optional: true,
    );
  }
  if (RegExp(r'^Banish chosen character$', caseSensitive: false).hasMatch(text)) {
    return ScriptedEffect(
      op: ScriptOp.banish,
      raw: sentence,
      characterOnly: true,
    );
  }
  if (RegExp(
    r'^Exert chosen opposing character$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return const ScriptedEffect(
      op: ScriptOp.exert,
      raw: 'Exert chosen opposing character.',
      opposingOnly: true,
      characterOnly: true,
    );
  }
  if (RegExp(r'^Ready chosen character$', caseSensitive: false).hasMatch(text)) {
    return ScriptedEffect(op: ScriptOp.ready, raw: sentence, characterOnly: true);
  }
  if (RegExp(r'^Draw a card$', caseSensitive: false).hasMatch(text)) {
    return ScriptedEffect(op: ScriptOp.draw, amount: 1, raw: sentence);
  }
  final draw = RegExp(
    r'^Draw (\d+) cards$',
    caseSensitive: false,
  ).firstMatch(text);
  if (draw != null) {
    return ScriptedEffect(
      op: ScriptOp.draw,
      amount: int.parse(draw.group(1)!),
      raw: sentence,
    );
  }
  final lore = RegExp(r'^Gain (\d+) lore$', caseSensitive: false).firstMatch(text);
  if (lore != null) {
    return ScriptedEffect(
      op: ScriptOp.lore,
      amount: int.parse(lore.group(1)!),
      raw: sentence,
    );
  }
  if (RegExp(
    r'^Put the top card of your deck into your inkwell facedown and exerted$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return ScriptedEffect(op: ScriptOp.inkTop, raw: sentence);
  }
  return null;
}
