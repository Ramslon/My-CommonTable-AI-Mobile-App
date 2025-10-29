import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:commontable_ai_app/core/services/supabase_service.dart';

class DiagnosticsResult {
  final ServiceStatus gemini;
  final ServiceStatus openai;
  final ServiceStatus huggingFace;
  final ServiceStatus supabase;
  final DateTime completedAt;

  const DiagnosticsResult({
    required this.gemini,
    required this.openai,
    required this.huggingFace,
    required this.supabase,
    required this.completedAt,
  });
}

class ServiceStatus {
  final bool configured;
  final bool reachable;
  final String message;

  const ServiceStatus({
    required this.configured,
    required this.reachable,
    required this.message,
  });
}

class DiagnosticsService {
  Future<DiagnosticsResult> run() async {
    final gemini = await _checkGemini();
    final openai = await _checkOpenAI();
    final hf = await _checkHF();
    final sb = await _checkSupabase();
    return DiagnosticsResult(
      gemini: gemini,
      openai: openai,
      huggingFace: hf,
      supabase: sb,
      completedAt: DateTime.now(),
    );
  }

  Future<ServiceStatus> _checkGemini() async {
  final key = (dotenv.maybeGet('GEMINI_API_KEY') ?? '').isNotEmpty
    ? dotenv.get('GEMINI_API_KEY')
    : const String.fromEnvironment('GEMINI_API_KEY');
  final model = (dotenv.maybeGet('GEMINI_MODEL') ?? '').isNotEmpty
    ? dotenv.get('GEMINI_MODEL')
    : const String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-1.5-flash');
    if (key.isEmpty) {
      return const ServiceStatus(configured: false, reachable: false, message: 'GEMINI_API_KEY missing');
    }
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
      final body = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'ping'}
            ]
          }
        ]
      };
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return const ServiceStatus(configured: true, reachable: true, message: 'OK');
      } else {
        return ServiceStatus(configured: true, reachable: false, message: 'HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      return ServiceStatus(configured: true, reachable: false, message: 'Error: $e');
    }
  }

  Future<ServiceStatus> _checkHF() async {
  final key = (dotenv.maybeGet('HF_API_KEY') ?? '').isNotEmpty
    ? dotenv.get('HF_API_KEY')
    : const String.fromEnvironment('HF_API_KEY');
  final model = (dotenv.maybeGet('HF_MODEL') ?? '').isNotEmpty
    ? dotenv.get('HF_MODEL')
    : const String.fromEnvironment('HF_MODEL', defaultValue: 'Qwen/Qwen2.5-3B-Instruct');
    if (key.isEmpty) {
      return const ServiceStatus(configured: false, reachable: false, message: 'HF_API_KEY missing');
    }
    try {
      final uri = Uri.parse('https://api-inference.huggingface.co/models/$model');
      final headers = {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'};
      final body = jsonEncode({'inputs': 'ping', 'parameters': {'max_new_tokens': 1}});
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 12));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return const ServiceStatus(configured: true, reachable: true, message: 'OK');
      } else {
        return ServiceStatus(configured: true, reachable: false, message: 'HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      return ServiceStatus(configured: true, reachable: false, message: 'Error: $e');
    }
  }

  Future<ServiceStatus> _checkSupabase() async {
  final url = (dotenv.maybeGet('SUPABASE_URL') ?? '').isNotEmpty
    ? dotenv.get('SUPABASE_URL')
    : const String.fromEnvironment('SUPABASE_URL');
  final key = (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '').isNotEmpty
    ? dotenv.get('SUPABASE_ANON_KEY')
    : const String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || key.isEmpty) {
      return const ServiceStatus(configured: false, reachable: false, message: 'SUPABASE_URL/ANON_KEY missing');
    }
    try {
      if (!SupabaseService.isConfigured) {
        await SupabaseService.init(url: url, anonKey: key);
      }
      final rows = await SupabaseService.fetchRecipeItems(limit: 1);
      return ServiceStatus(
        configured: true,
        reachable: true,
        message: 'OK${rows.isNotEmpty ? ' (${rows.length} row sample)' : ''}',
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Supabase diag failed: $e');
      }
      return ServiceStatus(configured: true, reachable: false, message: 'Error: $e');
    }
  }

  Future<ServiceStatus> _checkOpenAI() async {
    final key = (dotenv.maybeGet('OPENAI_API_KEY') ?? '').isNotEmpty
        ? dotenv.get('OPENAI_API_KEY')
        : (dotenv.maybeGet('OPENAI_KEY') ?? '').isNotEmpty
            ? dotenv.get('OPENAI_KEY')
            : const String.fromEnvironment('OPENAI_API_KEY', defaultValue: String.fromEnvironment('OPENAI_KEY'));
    final model = (dotenv.maybeGet('OPENAI_MODEL') ?? '').isNotEmpty
        ? dotenv.get('OPENAI_MODEL')
        : const String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini');
    if (key.isEmpty) {
      return const ServiceStatus(configured: false, reachable: false, message: 'OPENAI_API_KEY missing');
    }
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final headers = {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'};
      final body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': 'diagnostic'},
          {'role': 'user', 'content': 'ping'},
        ],
        'max_tokens': 1,
      });
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 12));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return const ServiceStatus(configured: true, reachable: true, message: 'OK');
      }
      return ServiceStatus(configured: true, reachable: false, message: 'HTTP ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      return ServiceStatus(configured: true, reachable: false, message: 'Error: $e');
    }
  }
}
