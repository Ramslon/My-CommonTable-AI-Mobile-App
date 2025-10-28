import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:commontable_ai_app/core/models/meal_plan.dart';

/// Offline cache keys
const _kBox = 'offline_cache';
const _kMealPlan = 'meal_plan';
const _kHealthTips = 'health_tips';
const _kAiInsights = 'ai_insights';
const _kLastSynced = 'last_synced';

class OfflineCacheService {
  OfflineCacheService._internal();
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;

  Box? _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      // No adapters required; we store Maps/Lists/Strings
    }
    _box ??= await Hive.openBox(_kBox);
  }

  Future<void> clear() async {
    await _box?.clear();
  }

  // Meal plan
  Future<void> saveMealPlan(MealPlan plan) async {
    await _ensure();
    await _box!.put(_kMealPlan, plan.toMap());
  }

  Future<MealPlan?> getMealPlan() async {
    await _ensure();
    final map = _box!.get(_kMealPlan);
    if (map is Map) {
      return MealPlan.fromMap(map.cast<String, dynamic>());
    }
    return null;
  }

  // Health tips (simple list of strings)
  Future<void> saveHealthTips(List<String> tips) async {
    await _ensure();
    await _box!.put(_kHealthTips, tips);
  }

  Future<List<String>> getHealthTips() async {
    await _ensure();
    final val = _box!.get(_kHealthTips);
    if (val is List) return val.whereType<String>().toList();
    return const [];
  }

  // AI insights (latest cached string)
  Future<void> saveAiInsights(String insights) async {
    await _ensure();
    await _box!.put(_kAiInsights, insights);
  }

  Future<String?> getAiInsights() async {
    await _ensure();
    final val = _box!.get(_kAiInsights);
    return val is String ? val : null;
  }

  Future<void> setLastSynced(DateTime dt) async {
    await _ensure();
    await _box!.put(_kLastSynced, dt.toIso8601String());
  }

  Future<DateTime?> getLastSynced() async {
    await _ensure();
    final s = _box!.get(_kLastSynced);
    if (s is String) {
      return DateTime.tryParse(s);
    }
    return null;
  }

  Future<void> _ensure() async {
    if (_box == null || !(_box!.isOpen)) {
      _box = await Hive.openBox(_kBox);
    }
  }
}
