import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';

class ThemeSettings extends ChangeNotifier {
  static final ThemeSettings _instance = ThemeSettings._internal();
  factory ThemeSettings() => _instance;
  ThemeSettings._internal();

  ThemeMode _mode = ThemeMode.system;
  Locale? _locale;

  ThemeMode get mode => _mode;
  Locale? get locale => _locale;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final modeStr = await AppSettings().getThemeMode();
    _mode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final code = sp.getString('language_code');
    _locale = code == null ? null : Locale(code);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await AppSettings().setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
    notifyListeners();
  }

  Future<void> setLocale(String? code) async {
    _locale = code == null ? null : Locale(code);
    await AppSettings().setLanguageCode(code);
    // Propagate language to Firebase Auth so any emails or auth UIs use the selected language.
    try {
      if (FirebaseBoot.available && code != null) {
        await FirebaseAuth.instance.setLanguageCode(code);
      }
    } catch (_) {}
    notifyListeners();
  }
}
