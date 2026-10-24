import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../features/cards/lorcana_card.dart';

class CardCatalog extends ChangeNotifier {
  static const metadataUrl = 'https://lorcanajson.org/files/current/en/metadata.json';
  static const cardsUrl = 'https://lorcanajson.org/files/current/en/allCards.json';

  List<LorcanaCard> cards = [];
  Map<int, LorcanaCard> byId = {};
  String? generatedOn;
  String? formatVersion;
  String? error;
  String status = 'Base ainda não carregada.';
  bool loading = false;
  double? progress;

  Database? _db;

  Future<void> load({bool force = false}) async {
    if (loading) return;
    loading = true;
    error = null;
    progress = null;
    status = 'Abrindo a base local…';
    notifyListeners();
    try {
      await _open();
      final count = await _count();
      String? remoteOn;
      try {
        status = 'Conferindo o LorcanaJSON…';
        notifyListeners();
        remoteOn = await _fetchGeneratedOn();
      } catch (failure) {
        if (count == 0) throw Exception(failure.toString());
        error = 'Sem rede. Usando o cache local.';
      }
      final localOn = await _meta('generatedOn');
      final stale = remoteOn != null && remoteOn != localOn;
      if (count == 0 || force || stale) {
        await _download();
      }
      await _readAll();
      status = '${cards.length} cartas · LorcanaJSON ${generatedOn ?? ''}'.trim();
    } catch (failure) {
      error = 'Falha ao carregar as cartas: $failure';
      status = error!;
    } finally {
      loading = false;
      progress = null;
      notifyListeners();
    }
  }

  Future<void> _open() async {
    if (_db != null) return;
    final root = await getApplicationSupportDirectory();
    final folder = Directory(p.join(root.path, 'LorcArcana'));
    await folder.create(recursive: true);
    _db = await databaseFactory.openDatabase(
      p.join(folder.path, 'cards.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cards (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              version TEXT,
              full_name TEXT NOT NULL,
              simple_name TEXT NOT NULL,
              names TEXT NOT NULL,
              kind TEXT NOT NULL,
              inks TEXT NOT NULL,
              cost INTEGER NOT NULL,
              inkwell INTEGER NOT NULL,
              strength INTEGER,
              willpower INTEGER,
              lore INTEGER,
              move_cost INTEGER,
              subtypes TEXT NOT NULL,
              full_text TEXT NOT NULL,
              effects TEXT NOT NULL,
              abilities TEXT NOT NULL,
              keywords TEXT NOT NULL,
              thumb TEXT,
              image TEXT,
              set_code TEXT NOT NULL,
              set_name TEXT NOT NULL,
              rarity TEXT NOT NULL,
              copy_limit INTEGER,
              unlimited INTEGER NOT NULL,
              core_legal INTEGER NOT NULL,
              infinity_legal INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_cards_simple ON cards(simple_name)',
          );
          await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)',
          );
        },
      ),
    );
  }

  Future<int> _count() async {
    final rows = await _db!.rawQuery('SELECT COUNT(*) AS n FROM cards');
    final value = rows.first['n'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<String?> _meta(String key) async {
    final rows = await _db!.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<void> _putMeta(DatabaseExecutor db, String key, String value) {
    return db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> _fetchGeneratedOn() async {
    final response = await http
        .get(Uri.parse(metadataUrl), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} ao ler metadados.');
    }
    final json = jsonDecode(response.body);
    if (json is! Map || json['generatedOn'] == null) {
      throw Exception('Metadados sem data de geração.');
    }
    return json['generatedOn'].toString();
  }

  Future<void> _download() async {
    status = 'Baixando as cartas…';
    progress = 0;
    notifyListeners();
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(cardsUrl));
      request.headers.addAll(_headers);
      final response = await client.send(request).timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} ao baixar as cartas.');
      }
      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      var reported = 0;
      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        if (received - reported > 250000) {
          reported = received;
          progress = total == 0 ? null : received / total;
          status = total == 0
              ? 'Baixando as cartas…'
              : 'Baixando as cartas… ${(received / total * 100).round()}%';
          notifyListeners();
        }
      }
      status = 'Organizando a base…';
      progress = null;
      notifyListeners();
      final payload = await compute(
        rowsFromLorcanaJson,
        utf8.decode(builder.takeBytes()),
      );
      final rawRows = payload['rows'];
      if (rawRows is! List || rawRows.isEmpty) {
        throw Exception('A base não trouxe cartas.');
      }
      final rows = <Map<String, Object?>>[
        for (final row in rawRows)
          if (row is Map) Map<String, Object?>.from(row),
      ];
      final generated = payload['generatedOn']?.toString() ?? '';
      final version = payload['formatVersion']?.toString() ?? '';
      await _db!.transaction((txn) async {
        await txn.delete('cards');
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert('cards', row);
        }
        await batch.commit(noResult: true);
        await _putMeta(txn, 'generatedOn', generated);
        await _putMeta(txn, 'formatVersion', version);
      });
    } finally {
      client.close();
    }
  }

  Future<void> _readAll() async {
    final rows = await _db!.query('cards', orderBy: 'cost, full_name');
    cards = rows.map(LorcanaCard.fromRow).toList();
    byId = {for (final card in cards) card.id: card};
    generatedOn = await _meta('generatedOn');
    formatVersion = await _meta('formatVersion');
  }

  static const _headers = {'User-Agent': 'LorcArcana/1.0'};
}
