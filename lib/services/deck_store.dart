import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SavedDeck {
  const SavedDeck({required this.name, required this.file, required this.ids});

  final String name;
  final File file;
  final List<int> ids;
}

class DeckStore {
  Future<Directory> folder() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'LorcArcana', 'decks'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<SavedDeck>> loadAll() async {
    final dir = await folder();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.deck'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files.map(_read).toList();
  }

  Future<SavedDeck> save(String name, List<int> ids) async {
    final dir = await folder();
    final safe = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    final fileName = safe.isEmpty ? 'deck' : safe;
    final file = File(p.join(dir.path, '$fileName.deck'));
    final buffer = StringBuffer('#name $name\n#main\n');
    for (final id in ids) {
      buffer.writeln(id);
    }
    await file.writeAsString(buffer.toString());
    return _read(file);
  }

  SavedDeck _read(File file) {
    final content = file.readAsStringSync();
    var name = p.basenameWithoutExtension(file.path);
    final ids = <int>[];
    for (final line in content.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#name ')) {
        name = trimmed.substring(6).trim();
        continue;
      }
      if (trimmed.startsWith('#')) continue;
      final id = int.tryParse(trimmed);
      if (id != null) ids.add(id);
    }
    return SavedDeck(name: name, file: file, ids: ids);
  }
}
