import 'dart:math';

/// Service to generate nutrition insights.
///
/// In production, wire this to Gemini or Hugging Face by sending the
/// current intake map and optionally the recommended targets to your model.
/// Keep prompts short and specific, and return 3-5 bullet guidance points.
class NutritionInsightsService {
  Future<String> generateInsights({required Map<String, double> intake}) async {
    // Simulated latency
    await Future.delayed(const Duration(milliseconds: 600));

    // Generate a simple heuristic-based summary for now
    final calories = intake['Calories (kcal)'] ?? 0;
    final protein = intake['Protein (g)'] ?? 0;
  final carbs = intake['Carbs (g)'] ?? 0;
    final fat = intake['Fat (g)'] ?? 0;
    final fiber = intake['Fiber (g)'] ?? 0;
    final sodium = intake['Sodium (mg)'] ?? 0;

    final tips = <String>[];
    if (protein < 50) tips.add('Protein is a bit low today — consider adding eggs, beans, or yogurt.');
    if (fiber < 28) tips.add('Fiber intake is under target — add veggies, oats, or legumes.');
    if (sodium > 2300) tips.add('Sodium appears high — reduce processed foods and salty snacks.');
    if (calories < 1800) tips.add('Calories might be a bit low — ensure you are fueling enough for your activity.');
    if (fat > 80) tips.add('Fat may be high — opt for leaner proteins and watch cooking oils.');
  if (carbs < 200) tips.add('Carbs look a little low — whole grains can help sustain energy.');
  if (tips.isEmpty) tips.add('Nice balance overall — keep it up! Consider seasonal fruits and hydration.');

    // Shuffle to vary messages a bit
    tips.shuffle(Random());

  return 'Based on your recent intake, here are some suggestions:\n\n${tips.map((t) => '• $t').join('\n')}';
  }

  // Example skeleton for a real LLM integration
  // Future<String> generateInsightsWithLLM({required Map<String,double> intake}) async {
  //   final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
  //   if (apiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');
  //   // Call your backend or Gemini/HF directly with secure auth.
  // }
}
