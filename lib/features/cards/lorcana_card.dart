import 'dart:convert';

enum CardKind { character, action, item, location }

enum Ink { amber, amethyst, emerald, ruby, sapphire, steel }

class CardKeyword {
  const CardKeyword(this.name, [this.value]);

  final String name;
  final int? value;

  Map<String, Object?> toJson() => {'name': name, 'value': value};

  factory CardKeyword.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    return CardKeyword(
      json['name']?.toString() ?? '',
      value is num ? value.toInt() : null,
    );
  }
}

class CardAbility {
  const CardAbility({
    required this.type,
    required this.name,
    required this.text,
    required this.costsText,
    required this.exertCost,
    required this.inkCost,
    required this.automatedCost,
  });

  final String type;
  final String name;
  final String text;
  final String costsText;
  final bool exertCost;
  final int inkCost;
  final bool automatedCost;

  Map<String, Object?> toJson() => {
    'type': type,
    'name': name,
    'text': text,
    'costsText': costsText,
    'exertCost': exertCost,
    'inkCost': inkCost,
    'automatedCost': automatedCost,
  };

  factory CardAbility.fromJson(Map<String, Object?> json) {
    return CardAbility(
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      costsText: json['costsText']?.toString() ?? '',
      exertCost: json['exertCost'] == true,
      inkCost: json['inkCost'] is num ? (json['inkCost'] as num).toInt() : 0,
      automatedCost: json['automatedCost'] == true,
    );
  }

  factory CardAbility.fromApi(Map<dynamic, dynamic> json) {
    final costs = json['costsText']?.toString() ?? '';
    final parsed = _parseCost(costs);
    return CardAbility(
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      text: json['effect']?.toString() ?? json['fullText']?.toString() ?? '',
      costsText: costs,
      exertCost: parsed.exert,
      inkCost: parsed.ink,
      automatedCost: parsed.automated,
    );
  }
}

class LorcanaCard {
  const LorcanaCard({
    required this.id,
    required this.name,
    this.version = '',
    required this.fullName,
    required this.simpleName,
    required this.names,
    required this.kind,
    required this.inks,
    required this.cost,
    required this.inkwell,
    this.strength,
    this.willpower,
    this.lore,
    this.moveCost,
    this.subtypes = const [],
    this.fullText = '',
    this.effects = const [],
    this.abilities = const [],
    this.keywords = const [],
    this.thumb,
    this.image,
    this.setCode = '',
    this.setName = '',
    this.rarity = '',
    this.copyLimit,
    this.unlimitedCopies = false,
    this.coreLegal = false,
    this.infinityLegal = false,
  });

  final int id;
  final String name;
  final String version;
  final String fullName;
  final String simpleName;
  final List<String> names;
  final CardKind kind;
  final List<Ink> inks;
  final int cost;
  final bool inkwell;
  final int? strength;
  final int? willpower;
  final int? lore;
  final int? moveCost;
  final List<String> subtypes;
  final String fullText;
  final List<String> effects;
  final List<CardAbility> abilities;
  final List<CardKeyword> keywords;
  final String? thumb;
  final String? image;
  final String setCode;
  final String setName;
  final String rarity;
  final int? copyLimit;
  final bool unlimitedCopies;
  final bool coreLegal;
  final bool infinityLegal;

  bool get isSong => subtypes.any((type) => type.toLowerCase() == 'song');

  /// Null quando a carta não tem teto de cópias.
  int? get maxInDeck => unlimitedCopies ? null : (copyLimit ?? 4);

  bool hasKeyword(String keyword) {
    final wanted = keyword.toLowerCase();
    return keywords.any((entry) => entry.name.toLowerCase() == wanted);
  }

  int? keywordNumber(String keyword) {
    final wanted = keyword.toLowerCase();
    for (final entry in keywords) {
      if (entry.name.toLowerCase() == wanted) return entry.value;
    }
    return null;
  }

  bool sharesName(LorcanaCard other) {
    final own = names.map((entry) => entry.toLowerCase()).toSet();
    final theirs = other.names.map((entry) => entry.toLowerCase()).toSet();
    return own.intersection(theirs).isNotEmpty;
  }

  factory LorcanaCard.fromApi(
    Map<dynamic, dynamic> json,
    Map<String, String> setNames,
  ) {
    final name = json['name']?.toString() ?? 'Sem nome';
    final version = json['version']?.toString() ?? '';
    final fullName = json['fullName']?.toString() ?? name;
    final names = <String>{name};
    final listed = json['names'];
    if (listed is List) {
      for (final entry in listed) {
        final text = entry.toString().trim();
        if (text.isNotEmpty) names.add(text);
      }
    }
    final keywords = <CardKeyword>[];
    final abilities = <CardAbility>[];
    final abilityList = json['abilities'];
    if (abilityList is List) {
      for (final entry in abilityList) {
        if (entry is! Map) continue;
        if (entry['type']?.toString() == 'keyword') {
          final keyword = entry['keyword']?.toString() ?? '';
          if (keyword.isEmpty) continue;
          final number = entry['keywordValueNumber'];
          keywords.add(
            CardKeyword(keyword, number is num ? number.toInt() : null),
          );
          continue;
        }
        abilities.add(CardAbility.fromApi(entry));
      }
    }
    final images = json['images'];
    String? thumb;
    String? image;
    if (images is Map) {
      thumb = images['thumbnail']?.toString();
      image = images['full']?.toString();
    }
    final setCode = json['setCode']?.toString() ?? '';
    final subtypes = _stringList(json['subtypes']);
    final effects = _stringList(json['effects']);
    return LorcanaCard(
      id: _asInt(json['id']),
      name: name,
      version: version,
      fullName: fullName,
      simpleName: json['simpleName']?.toString() ?? fullName.toLowerCase(),
      names: names.toList(),
      kind: _kind(json['type']?.toString() ?? ''),
      inks: _inks(json),
      cost: _asInt(json['cost']),
      inkwell: json['inkwell'] == true,
      strength: _maybeInt(json['strength']),
      willpower: _maybeInt(json['willpower']),
      lore: _maybeInt(json['lore']),
      moveCost: _maybeInt(json['moveCost']),
      subtypes: subtypes,
      fullText: json['fullText']?.toString() ?? '',
      effects: effects,
      abilities: abilities,
      keywords: keywords,
      thumb: thumb,
      image: image,
      setCode: setCode,
      setName: setNames[setCode] ?? setCode,
      rarity: json['rarity']?.toString() ?? '',
      copyLimit: json.containsKey('maxCopiesInDeck')
          ? _maybeInt(json['maxCopiesInDeck'])
          : null,
      unlimitedCopies:
          json.containsKey('maxCopiesInDeck') && json['maxCopiesInDeck'] == null,
      coreLegal: _formatAllowed(json, 'Core'),
      infinityLegal: _formatAllowed(json, 'Infinity'),
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'full_name': fullName,
      'simple_name': simpleName,
      'names': jsonEncode(names),
      'kind': kind.name,
      'inks': jsonEncode(inks.map((ink) => ink.name).toList()),
      'cost': cost,
      'inkwell': inkwell ? 1 : 0,
      'strength': strength,
      'willpower': willpower,
      'lore': lore,
      'move_cost': moveCost,
      'subtypes': jsonEncode(subtypes),
      'full_text': fullText,
      'effects': jsonEncode(effects),
      'abilities': jsonEncode(abilities.map((ability) => ability.toJson()).toList()),
      'keywords': jsonEncode(keywords.map((keyword) => keyword.toJson()).toList()),
      'thumb': thumb,
      'image': image,
      'set_code': setCode,
      'set_name': setName,
      'rarity': rarity,
      'copy_limit': copyLimit,
      'unlimited': unlimitedCopies ? 1 : 0,
      'core_legal': coreLegal ? 1 : 0,
      'infinity_legal': infinityLegal ? 1 : 0,
    };
  }

  factory LorcanaCard.fromRow(Map<String, Object?> row) {
    return LorcanaCard(
      id: _asInt(row['id']),
      name: row['name']?.toString() ?? '',
      version: row['version']?.toString() ?? '',
      fullName: row['full_name']?.toString() ?? '',
      simpleName: row['simple_name']?.toString() ?? '',
      names: _decodeStrings(row['names']),
      kind: CardKind.values.byName(row['kind']?.toString() ?? 'character'),
      inks: _decodeStrings(row['inks']).map(_inkNamed).whereType<Ink>().toList(),
      cost: _asInt(row['cost']),
      inkwell: row['inkwell'] == 1 || row['inkwell'] == true,
      strength: _maybeInt(row['strength']),
      willpower: _maybeInt(row['willpower']),
      lore: _maybeInt(row['lore']),
      moveCost: _maybeInt(row['move_cost']),
      subtypes: _decodeStrings(row['subtypes']),
      fullText: row['full_text']?.toString() ?? '',
      effects: _decodeStrings(row['effects']),
      abilities: _decodeMaps(row['abilities']).map(CardAbility.fromJson).toList(),
      keywords: _decodeMaps(row['keywords']).map(CardKeyword.fromJson).toList(),
      thumb: row['thumb']?.toString(),
      image: row['image']?.toString(),
      setCode: row['set_code']?.toString() ?? '',
      setName: row['set_name']?.toString() ?? '',
      rarity: row['rarity']?.toString() ?? '',
      copyLimit: _maybeInt(row['copy_limit']),
      unlimitedCopies: row['unlimited'] == 1 || row['unlimited'] == true,
      coreLegal: row['core_legal'] == 1 || row['core_legal'] == true,
      infinityLegal: row['infinity_legal'] == 1 || row['infinity_legal'] == true,
    );
  }
}

Map<String, Object?> rowsFromLorcanaJson(String source) {
  final data = jsonDecode(source);
  if (data is! Map) {
    throw const FormatException('A base não veio como objeto.');
  }
  final metadata = data['metadata'];
  final version = metadata is Map
      ? metadata['formatVersion']?.toString() ?? ''
      : '';
  if (!version.startsWith('2.')) {
    throw FormatException('Formato LorcanaJSON $version não é compatível.');
  }
  final generatedOn = metadata is Map
      ? metadata['generatedOn']?.toString() ?? ''
      : '';
  final setNames = <String, String>{};
  final sets = data['sets'];
  if (sets is Map) {
    sets.forEach((key, value) {
      if (value is Map && value['name'] != null) {
        setNames[key.toString()] = value['name'].toString();
      }
    });
  }
  final cards = data['cards'];
  final rows = <Map<String, Object?>>[];
  if (cards is List) {
    for (final entry in cards) {
      if (entry is! Map || entry['id'] == null) continue;
      final type = entry['type']?.toString() ?? '';
      if (type != 'Character' &&
          type != 'Action' &&
          type != 'Item' &&
          type != 'Location') {
        continue;
      }
      rows.add(LorcanaCard.fromApi(entry, setNames).toRow());
    }
  }
  return {
    'formatVersion': version,
    'generatedOn': generatedOn,
    'rows': rows,
  };
}

CardKind _kind(String type) {
  return switch (type) {
    'Action' => CardKind.action,
    'Item' => CardKind.item,
    'Location' => CardKind.location,
    _ => CardKind.character,
  };
}

List<Ink> _inks(Map<dynamic, dynamic> json) {
  final colors = json['colors'];
  if (colors is List && colors.isNotEmpty) {
    return colors.map((color) => _inkNamed(color.toString())).whereType<Ink>().toList();
  }
  final color = json['color']?.toString() ?? '';
  if (color.isEmpty) return const [];
  return color
      .split('-')
      .map(_inkNamed)
      .whereType<Ink>()
      .toList();
}

Ink? _inkNamed(String name) {
  return switch (name.toLowerCase()) {
    'amber' => Ink.amber,
    'amethyst' => Ink.amethyst,
    'emerald' => Ink.emerald,
    'ruby' => Ink.ruby,
    'sapphire' => Ink.sapphire,
    'steel' => Ink.steel,
    _ => null,
  };
}

bool _formatAllowed(Map<dynamic, dynamic> json, String format) {
  final formats = json['allowedInFormats'];
  if (formats is! Map) return false;
  final entry = formats[format];
  return entry is Map && entry['allowed'] == true;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((entry) => entry.toString()).toList();
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

int? _maybeInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

List<String> _decodeStrings(Object? value) {
  if (value is! String || value.isEmpty) return const [];
  final decoded = jsonDecode(value);
  if (decoded is! List) return const [];
  return decoded.map((entry) => entry.toString()).toList();
}

List<Map<String, Object?>> _decodeMaps(Object? value) {
  if (value is! String || value.isEmpty) return const [];
  final decoded = jsonDecode(value);
  if (decoded is! List) return const [];
  return decoded.whereType<Map>().map((entry) {
    return entry.map((key, item) => MapEntry(key.toString(), item));
  }).toList();
}

({bool exert, int ink, bool automated}) _parseCost(String costs) {
  final trimmed = costs.trim();
  if (trimmed.isEmpty) return (exert: false, ink: 0, automated: true);
  var exert = false;
  var ink = 0;
  var automated = true;
  for (final part in trimmed.split(',')) {
    final token = part.trim();
    if (token == '⟳') {
      exert = true;
      continue;
    }
    final match = RegExp(r'^(\d+)\s*⬡$').firstMatch(token);
    if (match != null) {
      ink += int.parse(match.group(1)!);
      continue;
    }
    automated = false;
  }
  return (exert: exert, ink: ink, automated: automated);
}
