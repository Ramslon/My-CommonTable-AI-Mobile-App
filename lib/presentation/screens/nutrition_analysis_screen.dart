import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:commontable_ai_app/core/services/health_sync_service.dart';

class NutritionAnalysisScreen extends StatefulWidget {
  const NutritionAnalysisScreen({super.key});

  @override
  State<NutritionAnalysisScreen> createState() =>
      _NutritionAnalysisScreenState();
}

class _NutritionAnalysisScreenState extends State<NutritionAnalysisScreen> {
  bool _loading = false;
  bool _loadingFirestore = false;
  String? _aiSummary;
  bool _live = true; // live analysis toggle
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _intakeSub;
  Timer? _debounce;

  // Daily intake vs recommended targets
  Map<String, double> _intake = {
    'Calories (kcal)': 1800,
    'Protein (g)': 55,
    'Carbs (g)': 230,
    'Fat (g)': 65,
    'Fiber (g)': 22,
    'Sodium (mg)': 2600,
  };
  final Map<String, double> _recommended = const {
    'Calories (kcal)': 2000,
    'Protein (g)': 50,
    'Carbs (g)': 275,
    'Fat (g)': 70,
    'Fiber (g)': 28,
    'Sodium (mg)': 2300,
  };

  final _insightsService = NutritionInsightsService();
  final _healthService = HealthSyncService();

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
    _subscribeIntakeRealtime();
  }

  void _subscribeIntakeRealtime() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final q = FirebaseFirestore.instance
          .collection('nutritionIntake')
          .orderBy('createdAt', descending: true)
          .limit(1);
      _intakeSub?.cancel();
      _intakeSub = q.snapshots().listen((snap) {
        if (!mounted) return;
        if (snap.docs.isEmpty) return;
        final data = snap.docs.first.data();
        setState(() {
          _intake = {
            'Calories (kcal)': (data['calories'] ?? _intake['Calories (kcal)']).toDouble(),
            'Protein (g)': (data['protein'] ?? _intake['Protein (g)']).toDouble(),
            'Carbs (g)': (data['carbs'] ?? _intake['Carbs (g)']).toDouble(),
            'Fat (g)': (data['fat'] ?? _intake['Fat (g)']).toDouble(),
            'Fiber (g)': (data['fiber'] ?? _intake['Fiber (g)']).toDouble(),
            'Sodium (mg)': (data['sodium'] ?? _intake['Sodium (mg)']).toDouble(),
          };
        });
        _scheduleAnalysisDebounced();
      });
    } catch (_) {
      // ignore; stays in manual mode
    }
  }

  void _scheduleAnalysisDebounced() {
    if (!_live) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_loading) return; // avoid piling requests
      _analyzeWithAI();
    });
  }

  Future<void> _loadFromFirestore() async {
    setState(() => _loadingFirestore = true);
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final firestore = FirebaseFirestore.instance;

      // Try to fetch the most recent daily intake
      final snap = await firestore
          .collection('nutritionIntake')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        // Expecting fields matching our keys; fallback to current values if missing
        setState(() {
          _intake = {
            'Calories (kcal)': (data['calories'] ?? _intake['Calories (kcal)']).toDouble(),
            'Protein (g)': (data['protein'] ?? _intake['Protein (g)']).toDouble(),
            'Carbs (g)': (data['carbs'] ?? _intake['Carbs (g)']).toDouble(),
            'Fat (g)': (data['fat'] ?? _intake['Fat (g)']).toDouble(),
            'Fiber (g)': (data['fiber'] ?? _intake['Fiber (g)']).toDouble(),
            'Sodium (mg)': (data['sodium'] ?? _intake['Sodium (mg)']).toDouble(),
          };
        });
      }
    } catch (e) {
      // Silent fallback to demo values
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using demo nutrition data (${e.toString()})')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFirestore = false);
    }
  }

  Future<void> _analyzeWithAI() async {
    setState(() {
      _loading = true;
      _aiSummary = null;
    });
    try {
      // Check current provider from settings at runtime
      final provider = await AppSettings().getInsightsProvider();
      final summary = await _insightsService.generateInsights(intake: _intake, provider: provider);
      if (mounted) setState(() => _aiSummary = summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiSummary = 'Failed to generate insights: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFromHealth() async {
    setState(() => _loadingFirestore = true);
    try {
      final pulled = await _healthService.pullNutrition();
      if (pulled.isNotEmpty) {
        setState(() {
          _intake = {
            'Calories (kcal)': pulled['calories']?.toDouble() ?? _intake['Calories (kcal)']!,
            'Protein (g)': pulled['protein']?.toDouble() ?? _intake['Protein (g)']!,
            'Carbs (g)': pulled['carbs']?.toDouble() ?? _intake['Carbs (g)']!,
            'Fat (g)': pulled['fat']?.toDouble() ?? _intake['Fat (g)']!,
            'Fiber (g)': pulled['fiber']?.toDouble() ?? _intake['Fiber (g)']!,
            'Sodium (mg)': pulled['sodium']?.toDouble() ?? _intake['Sodium (mg)']!,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Health sync not configured: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFirestore = false);
    }
  }

  @override
  void dispose() {
    _intakeSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Analysis'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => setState(() => _live = !_live),
            tooltip: _live ? 'Live analysis: On' : 'Live analysis: Off',
            icon: Icon(_live ? Icons.bolt : Icons.bolt_outlined, color: _live ? Colors.yellowAccent : Colors.white),
          ),
          IconButton(
            onPressed: _loadingFirestore ? null : _loadFromFirestore,
            tooltip: 'Load from Firestore',
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            onPressed: _loadingFirestore ? null : _syncFromHealth,
            tooltip: 'Sync from HealthKit/Google Fit',
            icon: const Icon(Icons.sync)
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _IntakeVsRecommendedChart(intake: _intake, recommended: _recommended),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _analyzeWithAI,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Analyze My Diet with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(minHeight: 2),

            if (_aiSummary != null)
              _AISummaryCard(summary: _aiSummary!),
          ],
        ),
      ),
    );
  }
}

class _IntakeVsRecommendedChart extends StatelessWidget {
  final Map<String, double> intake;
  final Map<String, double> recommended;

  const _IntakeVsRecommendedChart({required this.intake, required this.recommended});

  @override
  Widget build(BuildContext context) {
    final labels = recommended.keys.toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nutrient Intake vs Recommendation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[idx].split(' ').first, // short label
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(labels.length, (i) {
                    final label = labels[i];
                    final intakeVal = intake[label] ?? 0;
                    final recVal = recommended[label] ?? 0;
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 6,
                      barRods: [
                        BarChartRodData(toY: recVal, width: 10, color: Colors.green.shade200),
                        BarChartRodData(toY: intakeVal, width: 10, color: Colors.green.shade600),
                      ],
                    );
                  }),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                _Legend(color: Colors.green, label: 'Intake'),
                SizedBox(width: 12),
                _Legend(color: Color(0xFF9CCC65), label: 'Recommended'),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _AISummaryCard extends StatelessWidget {
  final String summary;
  const _AISummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(summary),
          ],
        ),
      ),
    );
  }
}
