import 'package:flutter/widgets.dart';

import 'services/card_database.dart';
import 'services/deck_store.dart';
import 'services/settings_store.dart';

class LorcanaScope extends InheritedWidget {
  const LorcanaScope({
    super.key,
    required this.catalog,
    required this.decks,
    required this.settings,
    required super.child,
  });

  final CardCatalog catalog;
  final DeckStore decks;
  final SettingsStore settings;

  static LorcanaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LorcanaScope>();
    assert(scope != null, 'LorcanaScope não encontrado.');
    return scope!;
  }

  @override
  bool updateShouldNotify(LorcanaScope oldWidget) {
    return catalog != oldWidget.catalog ||
        decks != oldWidget.decks ||
        settings != oldWidget.settings;
  }
}
