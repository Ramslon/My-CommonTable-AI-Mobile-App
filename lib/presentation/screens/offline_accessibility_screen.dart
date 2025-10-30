import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';
import 'package:commontable_ai_app/core/services/offline_cache_service.dart';
import 'package:commontable_ai_app/core/services/accessibility_settings.dart';
import 'package:commontable_ai_app/core/services/ai_meal_plan_service.dart';
import 'package:commontable_ai_app/core/models/meal_plan.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineAccessibilityScreen extends StatefulWidget {
  const OfflineAccessibilityScreen({super.key});

  @override
  State<OfflineAccessibilityScreen> createState() => _OfflineAccessibilityScreenState();
}

class _OfflineAccessibilityScreenState extends State<OfflineAccessibilityScreen> {
  bool _offline = false;
  DateTime? _lastSynced;
  double _textScale = 1.0;
  bool _voiceLogging = false;
  bool _busy = false;
  bool _prefetching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PrivacySettingsService().load();
    final last = await OfflineCacheService().getLastSynced();
    final access = AccessibilitySettings();
    setState(() {
      _offline = p.offlineMode;
      _lastSynced = last;
      _textScale = access.textScaleFactor;
      _voiceLogging = access.voiceLoggingEnabled;
    });
  }

  Future<void> _toggleOffline(bool v) async {
    setState(() => _offline = v);
    var p = await PrivacySettingsService().load();
    p = p.copyWith(offlineMode: v, updatedAt: DateTime.now());
    await PrivacySettingsService().save(p);
  }

  Future<void> _downloadMealPlan({MealPlanTimeframe timeframe = MealPlanTimeframe.weekly}) async {
    setState(() => _busy = true);
    try {
      final plan = AiMealPlanService().generatePlan(
        targetCalories: 2000,
        timeframe: timeframe,
        preference: DietaryPreference.omnivore,
        mealsPerDay: 3,
      );
      await OfflineCacheService().saveMealPlan(plan);
      await OfflineCacheService().setLastSynced(DateTime.now());
      final last = await OfflineCacheService().getLastSynced();
      if (mounted) {
        setState(() => _lastSynced = last);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal plan saved for offline use')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save meal plan: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadHealthTips() async {
    setState(() => _busy = true);
    try {
      final raw = await rootBundle.loadString('assets/data/health_tips.json');
      final data = (jsonDecode(raw) as List).whereType<String>().toList();
      await OfflineCacheService().saveHealthTips(data);
      await OfflineCacheService().setLastSynced(DateTime.now());
      final last = await OfflineCacheService().getLastSynced();
      if (mounted) {
        setState(() => _lastSynced = last);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health tips downloaded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download tips: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAiInsights() async {
    setState(() => _busy = true);
    try {
      final intake = <String, double>{
        'Calories (kcal)': 2000,
        'Protein (g)': 75,
        'Carbs (g)': 240,
        'Fat (g)': 70,
        'Fiber (g)': 22,
        'Sodium (mg)': 1900,
      };
      final provider = await AppSettings().getInsightsProvider();
      final insights = await NutritionInsightsService().generateInsights(intake: intake, provider: provider);
      await OfflineCacheService().saveAiInsights(insights);
      await OfflineCacheService().setLastSynced(DateTime.now());
      final last = await OfflineCacheService().getLastSynced();
      if (mounted) {
        setState(() => _lastSynced = last);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI insights cached for offline use')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cache insights: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prefetchOffers() async {
    setState(() => _prefetching = true);
    try {
      final p = await Connectivity().checkConnectivity();
      List<Map<String, dynamic>> list = [];
      if (!p.contains(ConnectivityResult.none)) {
        try {
          if (Firebase.apps.isEmpty) { await Firebase.initializeApp(); }
          final snap = await FirebaseDatabase.instance.ref('local_offers/global').get();
          final val = snap.value;
          if (val is List) {
            list = val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          } else if (val is Map) {
            // Convert map-of-maps to list
            list = (val.values.whereType<Map>()).map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (_) {}
      }
      if (list.isEmpty) {
        // Fallback to bundled mock
        final raw = await rootBundle.loadString('assets/data/promotions_mock.json');
        list = (jsonDecode(raw) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_offers', jsonEncode(list));
      await OfflineCacheService().setLastSynced(DateTime.now());
      final last = await OfflineCacheService().getLastSynced();
      if (mounted) {
        setState(() => _lastSynced = last);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local offers cached for offline use')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to prefetch offers: $e')));
      }
    } finally {
      if (mounted) setState(() => _prefetching = false);
    }
  }

  Future<void> _prefetchResources() async {
    setState(() => _prefetching = true);
    try {
      final p = await Connectivity().checkConnectivity();
      List<Map<String, dynamic>> list = [];
      if (!p.contains(ConnectivityResult.none)) {
        try {
          if (Firebase.apps.isEmpty) { await Firebase.initializeApp(); }
          final col = FirebaseFirestore.instance.collection('assistance_resources');
          final qs = await col.limit(200).get();
          list = qs.docs.map((d) => d.data()).toList();
        } catch (_) {}
      }
      if (list.isEmpty) {
        final raw = await rootBundle.loadString('assets/data/resources_mock.json');
        list = (jsonDecode(raw) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_resources', jsonEncode(list));
      await OfflineCacheService().setLastSynced(DateTime.now());
      final last = await OfflineCacheService().getLastSynced();
      if (mounted) {
        setState(() => _lastSynced = last);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resources cached for offline use')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to prefetch resources: $e')));
      }
    } finally {
      if (mounted) setState(() => _prefetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastStr = _lastSynced != null ? 'Last synced: ${_lastSynced!.toLocal()}' : 'Never synced';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline & Accessibility'),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              value: _offline,
              onChanged: _toggleOffline,
              title: const Text('Offline mode'),
              subtitle: const Text('Disable network requests and use stored data'),
            ),
            const SizedBox(height: 8),
            Text(lastStr, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 32),
            const Text('Download for offline use', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 8,
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _downloadMealPlan(timeframe: MealPlanTimeframe.daily),
                  icon: const Icon(Icons.download),
                  label: const Text('Daily Meal Plan'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _downloadMealPlan(timeframe: MealPlanTimeframe.weekly),
                  icon: const Icon(Icons.download),
                  label: const Text('Weekly Meal Plan'),
                ),
                ElevatedButton.icon(
                  onPressed: _downloadHealthTips,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Health Tips'),
                ),
                ElevatedButton.icon(
                  onPressed: _downloadAiInsights,
                  icon: const Icon(Icons.lightbulb),
                  label: const Text('Basic AI Insights'),
                ),
                ElevatedButton.icon(
                  onPressed: _prefetching ? null : _prefetchOffers,
                  icon: const Icon(Icons.local_offer),
                  label: Text(_prefetching ? 'Prefetching…' : 'Local Offers'),
                ),
                ElevatedButton.icon(
                  onPressed: _prefetching ? null : _prefetchResources,
                  icon: const Icon(Icons.handshake),
                  label: Text(_prefetching ? 'Prefetching…' : 'Resources & Assistance'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Accessibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('Text size'),
              subtitle: Slider(
                min: 0.8,
                max: 1.6,
                value: _textScale,
                divisions: 8,
                label: _textScale.toStringAsFixed(1),
                onChanged: (v) async {
                  setState(() => _textScale = v);
                  await AccessibilitySettings().setTextScaleFactor(v);
                },
              ),
            ),
            SwitchListTile(
              value: _voiceLogging,
              onChanged: (v) async {
                setState(() => _voiceLogging = v);
                await AccessibilitySettings().setVoiceLogging(v);
              },
              title: const Text('Voice note logging'),
              subtitle: const Text('Enable basic voice input logging where available'),
            ),
            ListTile(
              leading: const Icon(Icons.screen_search_desktop),
              title: const Text('Screen reader support'),
              subtitle: const Text('Most screens support TalkBack/VoiceOver. Use larger text and clear contrasts in Theme settings.'),
            ),
          ],
        ),
      ),
    );
  }
}
