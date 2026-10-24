import 'package:shared_preferences/shared_preferences.dart';

import '../features/deck/deck_rules.dart';

class SettingsStore {
  static const _format = 'format';
  static const _deck = 'deck';

  Future<PlayFormat> format() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_format);
    return PlayFormat.values.asNameMap()[name] ?? PlayFormat.casual;
  }

  Future<void> saveFormat(PlayFormat format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_format, format.name);
  }

  Future<String?> deckPath(int seat) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_deck$seat');
  }

  Future<void> saveDeckPath(int seat, String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('$_deck$seat');
      return;
    }
    await prefs.setString('$_deck$seat', path);
  }
}
