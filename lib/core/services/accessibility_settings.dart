import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._internal();
  static final AccessibilitySettings _instance = AccessibilitySettings._internal();
  factory AccessibilitySettings() => _instance;

  static const _kTextScale = 'access.textScale';
  static const _kVoiceLogging = 'access.voiceLogging';

  double _textScaleFactor = 1.0;
  bool _voiceLogging = false;

  double get textScaleFactor => _textScaleFactor;
  bool get voiceLoggingEnabled => _voiceLogging;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _textScaleFactor = (prefs.getDouble(_kTextScale) ?? 1.0).clamp(0.8, 1.6);
    _voiceLogging = prefs.getBool(_kVoiceLogging) ?? false;
  }

  Future<void> setTextScaleFactor(double v) async {
    _textScaleFactor = v.clamp(0.8, 1.6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, _textScaleFactor);
    notifyListeners();
  }

  Future<void> setVoiceLogging(bool v) async {
    _voiceLogging = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceLogging, v);
    notifyListeners();
  }
}
