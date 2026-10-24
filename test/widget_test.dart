import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorcarcana/app_scope.dart';
import 'package:lorcarcana/features/home/home_screen.dart';
import 'package:lorcarcana/services/card_database.dart';
import 'package:lorcarcana/services/deck_store.dart';
import 'package:lorcarcana/services/settings_store.dart';

void main() {
  testWidgets('o menu abre com o nome LorcArcana', (tester) async {
    await tester.pumpWidget(
      LorcanaScope(
        catalog: CardCatalog(),
        decks: DeckStore(),
        settings: SettingsStore(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('LorcArcana'), findsOneWidget);
    expect(find.text('Praticar'), findsOneWidget);
    expect(find.text('Editar deck'), findsOneWidget);
  });
}
