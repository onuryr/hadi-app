import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final LocaleNotifier localeNotifier;

enum AppLocaleMode { system, tr, en }

class LocaleNotifier extends ChangeNotifier {
  static const _prefKey = 'app_locale';

  AppLocaleMode _mode;

  LocaleNotifier._(this._mode);

  static Future<LocaleNotifier> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey) ?? 'system';
    final mode = switch (stored) {
      'tr' => AppLocaleMode.tr,
      'en' => AppLocaleMode.en,
      _ => AppLocaleMode.system,
    };
    return LocaleNotifier._(mode);
  }

  AppLocaleMode get mode => _mode;

  Locale? get locale => switch (_mode) {
    AppLocaleMode.system => null,
    AppLocaleMode.tr => const Locale('tr'),
    AppLocaleMode.en => const Locale('en'),
  };

  Future<void> setMode(AppLocaleMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, switch (mode) {
      AppLocaleMode.system => 'system',
      AppLocaleMode.tr => 'tr',
      AppLocaleMode.en => 'en',
    });
  }
}
