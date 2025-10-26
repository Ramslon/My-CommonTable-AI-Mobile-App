import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to generate nutrition insights.
///
/// In production, wire this to Gemini or Hugging Face by sending the
/// current intake map and optionally the recommended targets to your model.
/// Keep prompts short and specific, and return 3-5 bullet guidance points.
enum InsightsProvider { simulated, gemini, huggingFace }

class NutritionInsightsService {
  // Configure via --dart-define at build/run time
  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _geminiModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-1.5-flash');
  static const _hfKey = String.fromEnvironment('HF_API_KEY');
  static const _hfModel = String.fromEnvironment('HF_MODEL', defaultValue: 'Qwen/Qwen2.5-3B-Instruct');

  InsightsProvider get _autoProvider =>
      _geminiKey.isNotEmpty ? InsightsProvider.gemini : _hfKey.isNotEmpty ? InsightsProvider.huggingFace : InsightsProvider.simulated;

  Future<String> generateInsights({required Map<String, double> intake, InsightsProvider? provider}) async {
    final chosen = provider ?? _autoProvider;
    switch (chosen) {
      case InsightsProvider.gemini:
        try {
          return await _callGemini(intake);
        } catch (e) {
          return 'AI insights (Gemini) unavailable: $e\n\n${_simulatedSummary(intake)}';
        }
      case InsightsProvider.huggingFace:
        try {
          return await _callHuggingFace(intake);
        } catch (e) {
          return 'AI insights (HF) unavailable: $e\n\n${_simulatedSummary(intake)}';
        }
      case InsightsProvider.simulated:
        return _simulatedSummary(intake);
    }
  }

  String _simulatedSummary(Map<String, double> intake) {
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

    tips.shuffle(Random());
    return 'Based on your recent intake, here are some suggestions:\n\n${tips.map((t) => '• $t').join('\n')}';
  }

  Future<String> _callGemini(Map<String, double> intake) async {
    if (_geminiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey');

    final prompt = _buildPrompt(intake);
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    };

    final resp = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = (data['candidates'] as List?) ?? const [];
      if (candidates.isNotEmpty) {
        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = (content?['parts'] as List?) ?? const [];
        final text = parts.map((p) => p['text']).whereType<String>().join('\n').trim();
        if (text.isNotEmpty) return text;
      }
      throw Exception('No text in Gemini response');
    } else {
      throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<String> _callHuggingFace(Map<String, double> intake) async {
    if (_hfKey.isEmpty) throw Exception('Missing HF_API_KEY');
    final model = _hfModel;
    final uri = Uri.parse('https://api-inference.huggingface.co/models/$model');
    final prompt = _buildPrompt(intake);
    final headers = {
      'Authorization': 'Bearer $_hfKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'inputs': prompt, 'parameters': {'max_new_tokens': 180, 'temperature': 0.3}});

    final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      // HF responses vary by model. Try a few common shapes.
      if (data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is Map<String, dynamic>) {
          final txt = first['generated_text'] ?? first['summary_text'] ?? first['text'];
          if (txt is String && txt.trim().isNotEmpty) return txt.trim();
        } else if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
      } else if (data is Map<String, dynamic>) {
        final txt = data['generated_text'] ?? data['summary_text'] ?? data['text'];
        if (txt is String && txt.trim().isNotEmpty) return txt.trim();
      }
      throw Exception('Unexpected HF response shape');
    } else {
      throw Exception('HF HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  String _buildPrompt(Map<String, double> intake) {
    final calories = intake['Calories (kcal)']?.toStringAsFixed(0);
    final protein = intake['Protein (g)']?.toStringAsFixed(0);
    final carbs = intake['Carbs (g)']?.toStringAsFixed(0);
    final fat = intake['Fat (g)']?.toStringAsFixed(0);
    final fiber = intake['Fiber (g)']?.toStringAsFixed(0);
    final sodium = intake['Sodium (mg)']?.toStringAsFixed(0);

    return 'You are a nutrition coach. Given today\'s intake: ' 
        'calories=$calories kcal, protein=$protein g, carbs=$carbs g, fat=$fat g, fiber=$fiber g, sodium=$sodium mg. '
        'Provide 3-5 short, actionable suggestions to improve balance. Keep it under 80 words.';
  }
}
