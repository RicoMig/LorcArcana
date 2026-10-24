import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_scope.dart';
import 'features/home/home_screen.dart';
import 'services/card_database.dart';
import 'services/deck_store.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final catalog = CardCatalog();
  runApp(
    LorcArcanaApp(
      catalog: catalog,
      decks: DeckStore(),
      settings: SettingsStore(),
    ),
  );
  await catalog.load();
}

class LorcArcanaApp extends StatelessWidget {
  const LorcArcanaApp({
    super.key,
    required this.catalog,
    required this.decks,
    required this.settings,
  });

  final CardCatalog catalog;
  final DeckStore decks;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return LorcanaScope(
      catalog: catalog,
      decks: decks,
      settings: settings,
      child: MaterialApp(
        title: 'LorcArcana',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB9A7E6),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF10131A),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
