import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';

/// Service to generate nutrition insights.
///
/// In production, wire this to Gemini or Hugging Face by sending the
/// current intake map and optionally the recommended targets to your model.
/// Keep prompts short and specific, and return 3-5 bullet guidance points.
enum InsightsProvider { simulated, gemini, openai, huggingFace }

class NutritionInsightsService {
  // Load from .env first; fallback to --dart-define
  static String _env(String name, {String def = ''}) {
    final v = dotenv.maybeGet(name);
    if (v != null && v.isNotEmpty) return v;
    switch (name) {
      case 'GEMINI_API_KEY':
        return const String.fromEnvironment('GEMINI_API_KEY');
      case 'GEMINI_MODEL':
        return const String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-1.5-flash');
      case 'HF_API_KEY':
        return const String.fromEnvironment('HF_API_KEY');
      case 'HF_MODEL':
        return const String.fromEnvironment('HF_MODEL', defaultValue: 'Qwen/Qwen2.5-3B-Instruct');
      case 'OPENAI_API_KEY':
        return const String.fromEnvironment('OPENAI_API_KEY');
      case 'OPENAI_KEY':
        return const String.fromEnvironment('OPENAI_KEY');
      case 'OPENAI_MODEL':
        return const String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini');
      default:
        return def;
    }
  }

  static String get _geminiKey => _env('GEMINI_API_KEY');
  static String get _geminiModel => _env('GEMINI_MODEL', def: 'gemini-1.5-flash');
  static String get _hfKey => _env('HF_API_KEY');
  static String get _hfModel => _env('HF_MODEL', def: 'Qwen/Qwen2.5-3B-Instruct');
  static String get _openaiKey => _env('OPENAI_API_KEY').isNotEmpty ? _env('OPENAI_API_KEY') : _env('OPENAI_KEY');
  static String get _openaiModel => _env('OPENAI_MODEL', def: 'gpt-4o-mini');

  InsightsProvider get _autoProvider =>
      _geminiKey.isNotEmpty
          ? InsightsProvider.gemini
          : _openaiKey.isNotEmpty
              ? InsightsProvider.openai
              : _hfKey.isNotEmpty
                  ? InsightsProvider.huggingFace
                  : InsightsProvider.simulated;

  Future<String> generateInsights({required Map<String, double> intake, InsightsProvider? provider}) async {
    // Respect offline mode: force simulated output
    try {
      final p = await PrivacySettingsService().load();
      if (p.offlineMode) return _simulatedSummary(intake);
    } catch (_) {}
    final chosen = provider ?? _autoProvider;
    switch (chosen) {
      case InsightsProvider.gemini:
        try {
          return await _callGemini(intake);
        } catch (e) {
          return 'AI insights (Gemini) unavailable: $e\n\n${_simulatedSummary(intake)}';
        }
      case InsightsProvider.openai:
        try {
          final prompt = _buildPrompt(intake);
          return await _callOpenAIWithPrompt(prompt);
        } catch (e) {
          return 'AI insights (OpenAI) unavailable: $e\n\n${_simulatedSummary(intake)}';
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
    try {
      final p = await PrivacySettingsService().load();
      if (p.offlineMode) {
        final prompt = _buildWellnessPrompt(
          vitals: vitals ?? const {},
          activity: activity ?? const {},
          sleep: sleep ?? const {},
          dietHealthScore: dietHealthScore,
        );
        return _simulatedWellness(prompt);
      }
    } catch (_) {}
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
      case InsightsProvider.openai:
        try {
          return await _callOpenAIWithPrompt(prompt);
        } catch (e) {
          return 'AI wellness report (OpenAI) unavailable: $e\n\n${_simulatedWellness(prompt)}';
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
    try {
      final p = await PrivacySettingsService().load();
      if (p.offlineMode) {
        return _simulatedMood(mood, region, vegetarianOnly, useLocalStaples, budgetPerDay);
      }
    } catch (_) {}
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
      case InsightsProvider.openai:
        try {
          final prompt = _buildMoodPrompt(
            mood: mood,
            region: region,
            vegetarianOnly: vegetarianOnly,
            useLocalStaples: useLocalStaples,
            budgetPerDay: budgetPerDay,
          );
          return await _callOpenAIWithPrompt(prompt);
        } catch (e) {
          return 'AI mood support (OpenAI) unavailable: $e\n\n${_simulatedMood(mood, region, vegetarianOnly, useLocalStaples, budgetPerDay)}';
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
    final prompt = _buildPrompt(intake);
    return _geminiGenerate(prompt);
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
    return _geminiGenerate(prompt);
  }

  Future<String> _geminiGenerate(String prompt) async {
    // Try primary model; on 404, try alternates; on 429/503, retry with backoff
    final modelsToTry = <String>[
      _geminiModel,
      if (_geminiModel != 'gemini-1.5-flash-latest') 'gemini-1.5-flash-latest',
      if (_geminiModel != 'gemini-1.5-flash-8b') 'gemini-1.5-flash-8b',
    ];

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

    for (final model in modelsToTry) {
      int attempt = 0;
      while (attempt < 3) {
        attempt++;
        final uri = Uri.parse('https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$_geminiKey');
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
        }
        // 404 => model not found in region; try next model immediately
        if (resp.statusCode == 404) break;
        // 429/503 => backoff and retry
        if (resp.statusCode == 429 || resp.statusCode == 503) {
          final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '0') ?? 0;
          final delayMs = retryAfter > 0 ? retryAfter * 1000 : (400 * attempt);
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        // Other errors: throw and stop trying this model
        throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
      }
    }
    throw Exception('Gemini: all model attempts failed (404 or rate limits).');
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

  Future<String> _callOpenAIWithPrompt(String prompt) async {
    if (_openaiKey.isEmpty) throw Exception('Missing OPENAI_API_KEY (or OPENAI_KEY)');
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $_openaiKey',
      'Content-Type': 'application/json',
    };

    int attempt = 0;
    int maxTokens = 220;
    while (attempt < 3) {
      attempt++;
      final body = jsonEncode({
        'model': _openaiModel,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a nutrition and wellness coach. Keep answers concise, safe, and practical.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
        'max_tokens': maxTokens,
      });
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 25));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final choices = (data['choices'] as List?) ?? const [];
        if (choices.isNotEmpty) {
          final msg = choices.first['message'];
          final txt = (msg?['content'] as String?)?.trim();
          if (txt != null && txt.isNotEmpty) return txt;
        }
        throw Exception('No text in OpenAI response');
      }
      if (resp.statusCode == 429) {
        // Backoff using Retry-After or exponential; also reduce max_tokens on each retry
        final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '0') ?? 0;
        final delayMs = retryAfter > 0 ? retryAfter * 1000 : (500 * attempt);
        maxTokens = (maxTokens * 0.75).round().clamp(80, 220); // lower token usage
        await Future.delayed(Duration(milliseconds: delayMs));
        continue;
      }
      if (resp.statusCode == 503) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
        continue;
      }
      throw Exception('OpenAI HTTP ${resp.statusCode}: ${resp.body}');
    }
    throw Exception('OpenAI: rate limited; retries exhausted. Please try again later.');
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
