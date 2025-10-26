import 'package:shared_preferences/shared_preferences.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';

class AppSettings {
  static const _keyInsightsProvider = 'insights_provider';

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
}
