import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';

class DietAssessmentService {
  static const _calorieNinjasKey = String.fromEnvironment('CALORIE_NINJAS_KEY');

  /// Analyze a list of diet entries (free text foods) and return a scored assessment.
  /// If CALORIE_NINJAS_KEY is present, attempts to enrich macros via API; otherwise uses simulated lookup.
  Future<DietAssessmentResult> assessDiet({
    required List<String> foods,
    required String period, // 'daily' | 'weekly'
    NutritionInsightsService? insights,
  }) async {
    final intake = await _aggregateIntake(foods);

    // Simple heuristic health score (0-100)
    final score = _scoreIntake(intake, period: period);
    final risks = _detectRisks(intake, period: period);

    // AI suggestions (Gemini/HF/simulated)
    final svc = insights ?? NutritionInsightsService();
    final suggestions = await svc.generateInsights(intake: intake);

    return DietAssessmentResult(
      intake: intake,
      healthScore: score,
      risks: risks,
      suggestions: suggestions,
      createdAt: DateTime.now(),
      period: period,
    );
  }

  Future<Map<String, double>> _aggregateIntake(List<String> foods) async {
    final cleaned = foods.map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
    if (cleaned.isEmpty) {
      return {
        'Calories (kcal)': 0,
        'Protein (g)': 0,
        'Carbs (g)': 0,
        'Fat (g)': 0,
        'Fiber (g)': 0,
        'Sodium (mg)': 0,
      };
    }

    Map<String, double>? apiTotals;
    if (_calorieNinjasKey.isNotEmpty) {
      try {
        apiTotals = await _fetchCalorieNinjas(cleaned);
      } catch (_) {
        apiTotals = null;
      }
    }

    if (apiTotals != null) return apiTotals;

    // Simulated lookup for common foods (per serving)
    final db = <String, Map<String, double>>{
      'oats': {'cal': 150, 'pro': 5, 'carb': 27, 'fat': 3, 'fib': 4, 'na': 2},
      'yogurt': {'cal': 100, 'pro': 10, 'carb': 5, 'fat': 3, 'fib': 0, 'na': 60},
      'banana': {'cal': 105, 'pro': 1, 'carb': 27, 'fat': 0, 'fib': 3, 'na': 1},
      'eggs': {'cal': 150, 'pro': 12, 'carb': 1, 'fat': 10, 'fib': 0, 'na': 140},
      'rice': {'cal': 200, 'pro': 4, 'carb': 44, 'fat': 0, 'fib': 1, 'na': 0},
      'beans': {'cal': 170, 'pro': 10, 'carb': 30, 'fat': 1, 'fib': 7, 'na': 5},
      'chicken': {'cal': 165, 'pro': 31, 'carb': 0, 'fat': 4, 'fib': 0, 'na': 74},
      'sardine': {'cal': 190, 'pro': 22, 'carb': 0, 'fat': 11, 'fib': 0, 'na': 300},
      'plantain': {'cal': 180, 'pro': 2, 'carb': 48, 'fat': 0, 'fib': 4, 'na': 4},
      'vegetables': {'cal': 50, 'pro': 2, 'carb': 10, 'fat': 0, 'fib': 3, 'na': 40},
      'lentils': {'cal': 180, 'pro': 13, 'carb': 30, 'fat': 1, 'fib': 6, 'na': 5},
      'pasta': {'cal': 200, 'pro': 7, 'carb': 42, 'fat': 1, 'fib': 2, 'na': 3},
      'bread': {'cal': 160, 'pro': 6, 'carb': 28, 'fat': 2, 'fib': 3, 'na': 230},
      'peanut butter': {'cal': 190, 'pro': 7, 'carb': 8, 'fat': 16, 'fib': 2, 'na': 150},
    };

    double cal = 0, pro = 0, carb = 0, fat = 0, fib = 0, na = 0;
    for (final f in cleaned) {
      final key = db.keys.firstWhere((k) => f.toLowerCase().contains(k), orElse: () => '');
      if (key.isEmpty) continue;
      final v = db[key]!;
      cal += v['cal']!;
      pro += v['pro']!;
      carb += v['carb']!;
      fat += v['fat']!;
      fib += v['fib']!;
      na += v['na']!;
    }
    return {
      'Calories (kcal)': cal,
      'Protein (g)': pro,
      'Carbs (g)': carb,
      'Fat (g)': fat,
      'Fiber (g)': fib,
      'Sodium (mg)': na,
    };
  }

  Future<Map<String, double>> _fetchCalorieNinjas(List<String> foods) async {
    final query = foods.join(', ');
    final uri = Uri.parse('https://api.calorieninjas.com/v1/nutrition?query=${Uri.encodeQueryComponent(query)}');
    final resp = await http.get(uri, headers: {'X-Api-Key': _calorieNinjasKey}).timeout(const Duration(seconds: 20));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('CalorieNinjas HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];
    double cal = 0, pro = 0, carb = 0, fat = 0, fib = 0, na = 0;
    for (final it in items.whereType<Map>()) {
      cal += (it['calories'] as num?)?.toDouble() ?? 0;
      pro += (it['protein_g'] as num?)?.toDouble() ?? 0;
      carb += (it['carbohydrates_total_g'] as num?)?.toDouble() ?? 0;
      fat += (it['fat_total_g'] as num?)?.toDouble() ?? 0;
      fib += (it['fiber_g'] as num?)?.toDouble() ?? 0;
      na += (it['sodium_mg'] as num?)?.toDouble() ?? 0;
    }
    return {
      'Calories (kcal)': cal,
      'Protein (g)': pro,
      'Carbs (g)': carb,
      'Fat (g)': fat,
      'Fiber (g)': fib,
      'Sodium (mg)': na,
    };
  }

  double _scoreIntake(Map<String, double> intake, {required String period}) {
    // Daily targets
    const targetCal = 2400.0;
    const targetPro = 75.0;
    const targetFib = 28.0;
    const maxNa = 2300.0;

    double score = 100.0;
    final cal = intake['Calories (kcal)'] ?? 0;
    final pro = intake['Protein (g)'] ?? 0;
    final fib = intake['Fiber (g)'] ?? 0;
    final na = intake['Sodium (mg)'] ?? 0;

    // calorie deviation penalty
    final calDev = (cal - targetCal).abs() / targetCal; // proportion
    score -= (calDev * 30).clamp(0, 30); // up to -30

    if (pro < targetPro) score -= ((targetPro - pro) * 0.5).clamp(0, 20); // up to -20
    if (fib < targetFib) score -= ((targetFib - fib) * 0.7).clamp(0, 20); // up to -20
    if (na > maxNa) score -= (((na - maxNa) / 500)).clamp(0, 20); // -1 per 500mg over, up to -20

    return score.clamp(0, 100);
  }

  List<String> _detectRisks(Map<String, double> intake, {required String period}) {
    final risks = <String>[];
    final pro = intake['Protein (g)'] ?? 0;
    final fib = intake['Fiber (g)'] ?? 0;
    final na = intake['Sodium (mg)'] ?? 0;
    final cal = intake['Calories (kcal)'] ?? 0;

    if (pro < 50) risks.add('Low protein intake may affect satiety and muscle maintenance.');
    if (fib < 25) risks.add('Low fiber may impact gut health and blood sugar balance.');
    if (na > 2300) risks.add('High sodium may elevate blood pressure risk.');
    if (cal < 1600) risks.add('Very low calories may reduce energy and recovery.');
    if (cal > 3200) risks.add('High calories may lead to unwanted weight gain.');

    return risks;
  }
}

class DietAssessmentResult {
  final Map<String, double> intake;
  final double healthScore; // 0..100
  final List<String> risks;
  final String suggestions; // AI-generated text or simulated
  final DateTime createdAt;
  final String period;

  const DietAssessmentResult({
    required this.intake,
    required this.healthScore,
    required this.risks,
    required this.suggestions,
    required this.createdAt,
    required this.period,
  });
}