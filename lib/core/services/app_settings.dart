import 'package:shared_preferences/shared_preferences.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';

class AppSettings {
  static const _keyInsightsProvider = 'insights_provider';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyDailyReminderEnabled = 'daily_reminder_enabled';
  static const _keyThemeMode = 'theme_mode'; // system|light|dark
  static const _keyLanguage = 'language_code'; // e.g., en, fr, sw
  static const _keyCurrency = 'currency_code'; // kes|usd|eur
  static const _keyHideSignInReminder = 'hide_sign_in_reminder';
  static const _keySubscriptionTier = 'subscription_tier'; // basic|plus|premium

  Future<InsightsProvider> getInsightsProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keyInsightsProvider);
    switch (val) {
      case 'gemini':
        return InsightsProvider.gemini;
      case 'huggingFace':
        return InsightsProvider.huggingFace;
      case 'simulated':
      default:
        return InsightsProvider.simulated;
    }
  }

  Future<void> setInsightsProvider(InsightsProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final val = switch (provider) {
      InsightsProvider.gemini => 'gemini',
      InsightsProvider.huggingFace => 'huggingFace',
      InsightsProvider.simulated => 'simulated',
    };
    await prefs.setString(_keyInsightsProvider, val);
  }

  // Notifications
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  Future<bool> getDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDailyReminderEnabled) ?? false;
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDailyReminderEnabled, enabled);
  }

  // Theme mode
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  // Language
  Future<String?> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage);
  }

  Future<void> setLanguageCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_keyLanguage);
    } else {
      await prefs.setString(_keyLanguage, code);
    }
  }

  // Currency
  Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrency) ?? 'usd';
  }

  Future<void> setCurrencyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, code);
  }

  // Sign-in reminder visibility
  Future<bool> getHideSignInReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHideSignInReminder) ?? false;
  }

  Future<void> setHideSignInReminder(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideSignInReminder, hidden);
  }

  // Subscription tier (local cache for gating when offline)
  Future<String?> getSubscriptionTier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySubscriptionTier);
  }

  Future<void> setSubscriptionTier(String? tier) async {
    final prefs = await SharedPreferences.getInstance();
    if (tier == null) {
      await prefs.remove(_keySubscriptionTier);
    } else {
      await prefs.setString(_keySubscriptionTier, tier);
    }
  }
}
