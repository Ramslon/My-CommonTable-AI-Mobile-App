import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';
import 'package:commontable_ai_app/core/services/offline_cache_service.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';

/// Listens for connectivity changes and auto-syncs lightweight offline content
/// when internet reconnects and offline mode is disabled.
class OfflineSyncService {
  OfflineSyncService._internal();
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = false;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) async {
      final nowOnline = results.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      if (nowOnline && !_online) {
        _online = true;
        await _maybeSync();
      } else if (!nowOnline) {
        _online = false;
      }
    });
    // initial probe (fire-and-forget)
    Connectivity().checkConnectivity().then((results) {
      _online = results.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      if (_online) {
        _maybeSync();
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _maybeSync() async {
    try {
      final privacy = await PrivacySettingsService().load();
      if (privacy.offlineMode) return; // respect offline mode

      // Example sync: refresh basic AI insights using your selected provider
      final intake = <String, double>{
        'Calories (kcal)': 2000,
        'Protein (g)': 80,
        'Carbs (g)': 250,
        'Fat (g)': 70,
        'Fiber (g)': 25,
        'Sodium (mg)': 1800,
      };
      final insights = await NutritionInsightsService().generateInsights(intake: intake);
      await OfflineCacheService().saveAiInsights(insights);
      await OfflineCacheService().setLastSynced(DateTime.now());
    } catch (_) {
      // ignore sync errors silently
    }
  }
}
