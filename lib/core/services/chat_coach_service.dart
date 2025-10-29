import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';

/// Lightweight chat coach service supporting simulated, Gemini, OpenAI and HF.
class ChatCoachService {
  // Read from .env first, then from --dart-define fallback
  static String _env(String name, {String def = ''}) {
    final v = dotenv.maybeGet(name);
    if (v != null && v.isNotEmpty) return v;
    const empty = '';
    switch (name) {
      case 'GEMINI_API_KEY':
        return const String.fromEnvironment('GEMINI_API_KEY');
      case 'GEMINI_MODEL':
        return const String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-1.5-flash');
      case 'OPENAI_API_KEY':
        return const String.fromEnvironment('OPENAI_API_KEY');
      case 'OPENAI_KEY':
        return const String.fromEnvironment('OPENAI_KEY');
      case 'OPENAI_MODEL':
        return const String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini');
      case 'HF_API_KEY':
        return const String.fromEnvironment('HF_API_KEY');
      case 'HF_MODEL':
        return const String.fromEnvironment('HF_MODEL', defaultValue: 'Qwen/Qwen2.5-3B-Instruct');
      default:
        return def.isNotEmpty ? def : empty;
    }
  }

  static String get _geminiKey => _env('GEMINI_API_KEY');
  static String get _geminiModel => _env('GEMINI_MODEL', def: 'gemini-1.5-flash');
  static String get _openaiKey => _env('OPENAI_API_KEY').isNotEmpty ? _env('OPENAI_API_KEY') : _env('OPENAI_KEY');
  static String get _openaiModel => _env('OPENAI_MODEL', def: 'gpt-4o-mini');
  static String get _hfKey => _env('HF_API_KEY');
  static String get _hfModel => _env('HF_MODEL', def: 'Qwen/Qwen2.5-3B-Instruct');

  ChatProvider get autoProvider {
    if (_geminiKey.isNotEmpty) return ChatProvider.gemini;
    if (_openaiKey.isNotEmpty) return ChatProvider.openai;
    if (_hfKey.isNotEmpty) return ChatProvider.huggingFace;
    return ChatProvider.simulated;
  }

  Future<ChatReply> reply({required List<ChatTurn> history, ChatProvider? provider, ChatTopic topic = ChatTopic.generalHealth}) async {
    // Offline mode short-circuits to simulated response
    try {
      final p = await PrivacySettingsService().load();
      if (p.offlineMode) {
        return ChatReply(text: _simulate(history, topic), provider: ChatProvider.simulated, note: 'offline mode');
      }
    } catch (_) {}
    final chosen = provider ?? autoProvider;
    final themed = _injectPrimer(history, topic);
    switch (chosen) {
      case ChatProvider.gemini:
        try {
          final txt = await _callGemini(themed);
          return ChatReply(text: txt, provider: chosen);
        } catch (e) {
          return ChatReply(text: _simulate(history, topic), provider: ChatProvider.simulated, note: 'Gemini fallback: $e');
        }
      case ChatProvider.openai:
        try {
          final txt = await _callOpenAI(themed, topic: topic);
          return ChatReply(text: txt, provider: chosen);
        } catch (e) {
          return ChatReply(text: _simulate(history, topic), provider: ChatProvider.simulated, note: 'OpenAI fallback: $e');
        }
      case ChatProvider.huggingFace:
        try {
          final txt = await _callHF(themed, topic: topic);
          return ChatReply(text: txt, provider: chosen);
        } catch (e) {
          return ChatReply(text: _simulate(history, topic), provider: ChatProvider.simulated, note: 'HF fallback: $e');
        }
      case ChatProvider.simulated:
        return ChatReply(text: _simulate(history, topic), provider: chosen);
    }
  }

  List<ChatTurn> _injectPrimer(List<ChatTurn> history, ChatTopic topic) {
    final primer = _topicPrimer(topic);
    if (primer == null) return history;
    // Insert a leading user turn to act as a system-like primer for providers without system role
    return [
      ChatTurn(role: 'user', content: primer),
      ...history,
    ];
  }

  String? _topicPrimer(ChatTopic topic) {
    switch (topic) {
      case ChatTopic.motivation:
        return 'SYSTEM: You are a supportive health coach focused on motivation. Use short, encouraging messages with 2-4 actionable ideas.';
      case ChatTopic.dietAdvice:
        return 'SYSTEM: You are a nutrition coach. Provide concise diet advice (2-4 bullets) tailored to students and budget-friendly options when possible.';
      case ChatTopic.generalHealth:
        return 'SYSTEM: You are a friendly general health coach. Keep answers brief, practical, and safe. When unsure, recommend seeking professional care.';
    }
  }

  String _simulate(List<ChatTurn> history, ChatTopic topic) {
    final last = history.lastOrNull?.content.toLowerCase() ?? '';
    if (last.contains('protein')) {
      return 'Protein ideas: eggs, beans/lentils, yogurt, chicken, sardine. Aim ~1.2–2.0 g/kg body weight. Match with veggies + whole grains.';
    }
    if (last.contains('breakfast')) {
      return 'Balanced breakfast: oats + yogurt + banana + nuts; or eggs + wholegrain toast + fruit. Steady energy, fiber, and protein.';
    }
    if (last.contains('mood') || last.contains('stress') || last.contains('anxious') || last.contains('sad')) {
      return 'For mood support: try oats/whole grains, yogurt/ferments, beans/lentils, leafy greens, and a small piece of dark chocolate.';
    }
    if (last.contains('student') || last.contains('budget')) {
      return 'Budget-friendly: rice + beans + plantain; lentil stew with rice; sardine pasta; oats with peanut butter + banana.';
    }
    switch (topic) {
      case ChatTopic.motivation:
        return 'You\'ve got this. Try a 10-minute walk, a glass of water, and one small win to build momentum today.';
      case ChatTopic.dietAdvice:
        return 'Quick diet tip: build meals with protein + fiber + color. Example: beans + rice + greens + avocado.';
      case ChatTopic.generalHealth:
        return 'I\'m your AI coach. Ask about motivation, diet planning, or general health questions.';
    }
  }

  Future<String> _callGemini(List<ChatTurn> history) async {
    if (_geminiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey');
    final contents = history.map((h) => {
          'role': h.role == 'user' ? 'user' : 'model',
          'parts': [
            {'text': h.content}
          ]
        }).toList();
    final body = {'contents': contents};
    final resp = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = (data['candidates'] as List?) ?? const [];
      if (candidates.isNotEmpty) {
        final parts = (candidates.first['content']?['parts'] as List?) ?? const [];
        final text = parts.map((p) => p['text']).whereType<String>().join('\n').trim();
        if (text.isNotEmpty) return text;
      }
      throw Exception('No text in Gemini response');
    }
    throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
  }

  Future<String> _callOpenAI(List<ChatTurn> history, {required ChatTopic topic}) async {
  if (_openaiKey.isEmpty) throw Exception('Missing OPENAI_API_KEY (or OPENAI_KEY)');
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final messages = history
        .map((h) => {
              'role': h.role,
              'content': h.content,
            })
        .toList();
    // System primer keeps replies supportive and concise.
    messages.insert(0, {
      'role': 'system',
      'content': _topicPrimer(topic) ?? 'You are a supportive student nutrition coach. Be kind, concise, and actionable.'
    });
    final headers = {
      'Authorization': 'Bearer $_openaiKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'model': _openaiModel, 'messages': messages, 'temperature': 0.4, 'max_tokens': 200});
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
    throw Exception('OpenAI HTTP ${resp.statusCode}: ${resp.body}');
  }

  Future<String> _callHF(List<ChatTurn> history, {required ChatTopic topic}) async {
    if (_hfKey.isEmpty) throw Exception('Missing HF_API_KEY');
    final uri = Uri.parse('https://api-inference.huggingface.co/models/$_hfModel');
    final primer = _topicPrimer(topic) ?? '';
    final joined = ([if (primer.isNotEmpty) 'SYSTEM: $primer', ...history.map((h) => '${h.role.toUpperCase()}: ${h.content}')]).join('\n');
    final prompt = '$joined\nASSISTANT:';
    final headers = {'Authorization': 'Bearer $_hfKey', 'Content-Type': 'application/json'};
    final body = jsonEncode({'inputs': prompt, 'parameters': {'max_new_tokens': 200, 'temperature': 0.4}});
    final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 25));
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
    }
    throw Exception('HF HTTP ${resp.statusCode}: ${resp.body}');
  }
}

class ChatTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  const ChatTurn({required this.role, required this.content});
}

class ChatReply {
  final String text;
  final ChatProvider provider;
  final String? note;
  const ChatReply({required this.text, required this.provider, this.note});
}

enum ChatProvider { simulated, gemini, openai, huggingFace }

extension _LastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : this[length - 1];
}

enum ChatTopic { motivation, dietAdvice, generalHealth }