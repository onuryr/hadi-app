import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final ThemeNotifier themeNotifier;

class ThemeNotifier extends ChangeNotifier {
  static const _prefKey = 'theme_mode';

  ThemeMode _mode;

  ThemeNotifier._(this._mode);

  static Future<ThemeNotifier> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey) ?? 'system';
    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return ThemeNotifier._(mode);
  }

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
