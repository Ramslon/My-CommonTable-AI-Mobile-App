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

  /// Advanced lifestyle/wellness report combining wearable metrics and diet.
  /// Expects small numeric maps like { 'steps': 6500, 'hr_avg': 72 }.
  Future<String> generateWellnessReport({
    Map<String, double>? vitals,
    Map<String, double>? activity,
    Map<String, double>? sleep,
    double? dietHealthScore,
    InsightsProvider? provider,
  }) async {
    final chosen = provider ?? _autoProvider;
    final prompt = _buildWellnessPrompt(
      vitals: vitals ?? const {},
      activity: activity ?? const {},
      sleep: sleep ?? const {},
      dietHealthScore: dietHealthScore,
    );

    switch (chosen) {
      case InsightsProvider.gemini:
        try {
          return await _callGeminiWithPrompt(prompt);
        } catch (e) {
          return 'AI wellness report (Gemini) unavailable: $e\n\n${_simulatedWellness(prompt)}';
        }
      case InsightsProvider.huggingFace:
        try {
          return await _callHFWithPrompt(prompt);
        } catch (e) {
          return 'AI wellness report (HF) unavailable: $e\n\n${_simulatedWellness(prompt)}';
        }
      case InsightsProvider.simulated:
        return _simulatedWellness(prompt);
    }
  }

  /// Mood-based nutrition guidance using the same provider selection.
  Future<String> generateMoodSupport({
    required String mood,
    String? region,
    bool vegetarianOnly = false,
    bool useLocalStaples = true,
    double? budgetPerDay,
    InsightsProvider? provider,
  }) async {
    final chosen = provider ?? _autoProvider;
    switch (chosen) {
      case InsightsProvider.gemini:
        try {
          return await _callGeminiMood(
            mood: mood,
            region: region,
            vegetarianOnly: vegetarianOnly,
            useLocalStaples: useLocalStaples,
            budgetPerDay: budgetPerDay,
          );
        } catch (e) {
          return 'AI mood support (Gemini) unavailable: $e\n\n${_simulatedMood(mood, region, vegetarianOnly, useLocalStaples, budgetPerDay)}';
        }
      case InsightsProvider.huggingFace:
        try {
          return await _callHFMood(
            mood: mood,
            region: region,
            vegetarianOnly: vegetarianOnly,
            useLocalStaples: useLocalStaples,
            budgetPerDay: budgetPerDay,
          );
        } catch (e) {
          return 'AI mood support (HF) unavailable: $e\n\n${_simulatedMood(mood, region, vegetarianOnly, useLocalStaples, budgetPerDay)}';
        }
      case InsightsProvider.simulated:
        return _simulatedMood(mood, region, vegetarianOnly, useLocalStaples, budgetPerDay);
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

  Future<String> _callGeminiWithPrompt(String prompt) async {
    if (_geminiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey');
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

  Future<String> _callHFWithPrompt(String prompt) async {
    if (_hfKey.isEmpty) throw Exception('Missing HF_API_KEY');
    final model = _hfModel;
    final uri = Uri.parse('https://api-inference.huggingface.co/models/$model');
    final headers = {
      'Authorization': 'Bearer $_hfKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'inputs': prompt, 'parameters': {'max_new_tokens': 220, 'temperature': 0.3}});

    final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
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

  String _buildWellnessPrompt({
    required Map<String, double> vitals,
    required Map<String, double> activity,
    required Map<String, double> sleep,
    double? dietHealthScore,
  }) {
    final parts = <String>[];
    if (vitals.isNotEmpty) parts.add('Vitals: ${_kv(vitals)}');
    if (activity.isNotEmpty) parts.add('Activity: ${_kv(activity)}');
    if (sleep.isNotEmpty) parts.add('Sleep: ${_kv(sleep)}');
    if (dietHealthScore != null) parts.add('DietScore: ${dietHealthScore.toStringAsFixed(0)}');
    final ctx = parts.join(' | ');
  return 'You are a premium health coach. Using the data ($ctx), write a short wellness insight report:\n'
    '• 3-5 actionable bullets (stress, recovery, activity, nutrition)\n'
    '• Highlight 1 priority for today and 1 for the week\n'
    '• Keep under 120 words; avoid repetition; friendly, professional tone.';
  }

  String _kv(Map<String, double> m) => m.entries.map((e) => '${e.key}=${e.value.toStringAsFixed(0)}').join(', ');

  String _simulatedWellness(String promptEcho) {
    final bullets = [
      'Aim for a 20–30 min brisk walk today; add gentle mobility if stiff.',
      'Prioritize 7–8 hours sleep; keep a consistent wind-down and caffeine cutoff.',
      'Add 20–30 g protein at each meal; include leafy greens and high-fiber carbs.',
      'Hydrate: target 6–8 cups water; add electrolytes after sweaty activity.',
      'Mindfulness micro-breaks (2–3 min) between study/work blocks to lower stress load.',
    ];
    return 'Personalized Wellness Insights:\n\n${bullets.map((b) => '• $b').join('\n')}\n\nToday’s Priority: Get outside for a short walk.\nThis Week: Establish a sleep routine (same bedtime/wake time).';
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

  String _buildMoodPrompt({
    required String mood,
    String? region,
    bool vegetarianOnly = false,
    bool useLocalStaples = true,
    double? budgetPerDay,
  }) {
    final ctx = [
      if (region != null) 'region=$region',
      if (vegetarianOnly) 'vegetarianOnly=true',
      if (useLocalStaples) 'localStaples=true',
  if (budgetPerDay != null) 'budgetPerDay=${budgetPerDay.toStringAsFixed(0)}',
    ].join(', ');

    return 'You are a supportive student nutrition coach. The student feels "$mood". '
        '${ctx.isNotEmpty ? 'Context: $ctx. ' : ''}'
        'In 4-6 brief bullets, suggest foods/snacks/meals that may help mood (e.g., omega-3 fish, legumes, yogurt/fermented foods, oats/whole grains, leafy greens, dark chocolate in moderation). '
        'Include 2-3 budget-friendly ideas using local staples if possible. Keep it under 110 words. Be gentle and encouraging.';
  }

  String _simulatedMood(String mood, String? region, bool vegetarianOnly, bool useLocalStaples, double? budgetPerDay) {
    final tips = <String>[
      'Try oats with yogurt and banana for steady energy and gut support.',
      'Add beans or lentils for magnesium and fiber to support stress balance.',
      'Include a small portion of oily fish or sardine for omega-3s (or flax/chia if vegetarian).',
      'Leafy greens with a simple grain (rice or wholegrain bread) can be grounding.',
      'A square of dark chocolate with nuts can be a mindful study snack.',
    ];
    return 'For how you\'re feeling ($mood), here are supportive ideas:\n\n${tips.map((t) => '• $t').join('\n')}';
  }

  Future<String> _callGeminiMood({
    required String mood,
    String? region,
    bool vegetarianOnly = false,
    bool useLocalStaples = true,
    double? budgetPerDay,
  }) async {
    if (_geminiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey');
    final prompt = _buildMoodPrompt(
      mood: mood,
      region: region,
      vegetarianOnly: vegetarianOnly,
      useLocalStaples: useLocalStaples,
      budgetPerDay: budgetPerDay,
    );

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

  Future<String> _callHFMood({
    required String mood,
    String? region,
    bool vegetarianOnly = false,
    bool useLocalStaples = true,
    double? budgetPerDay,
  }) async {
    if (_hfKey.isEmpty) throw Exception('Missing HF_API_KEY');
    final model = _hfModel;
    final uri = Uri.parse('https://api-inference.huggingface.co/models/$model');
    final prompt = _buildMoodPrompt(
      mood: mood,
      region: region,
      vegetarianOnly: vegetarianOnly,
      useLocalStaples: useLocalStaples,
      budgetPerDay: budgetPerDay,
    );
    final headers = {
      'Authorization': 'Bearer $_hfKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'inputs': prompt, 'parameters': {'max_new_tokens': 180, 'temperature': 0.3}});

    final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
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
}
