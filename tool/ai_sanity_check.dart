// Minimal AI sanity checker for Gemini (v1) and OpenAI using environment variables.
// Usage (PowerShell):
//   $env:GEMINI_API_KEY = "<key>"; $env:OPENAI_API_KEY = "<key>"
//   dart run tool/ai_sanity_check.dart
// Or:
//   flutter pub run tool/ai_sanity_check.dart

import 'dart:convert';
import 'dart:io';

Future<_Resp> _postJson(Uri uri, Map<String, String> headers, Object body,
    {Duration timeout = const Duration(seconds: 45)}) async {
  final sw = Stopwatch()..start();
  final client = HttpClient();
  try {
    final req = await client.postUrl(uri).timeout(timeout);
    headers.forEach(req.headers.add);
    final payload = utf8.encode(jsonEncode(body));
    req.add(payload);
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join();
    sw.stop();
    return _Resp(res.statusCode, text, sw.elapsed);
  } finally {
    client.close(force: true);
  }
}

class _Resp {
  final int status;
  final String body;
  final Duration elapsed;
  _Resp(this.status, this.body, this.elapsed);
}

String _truncate(String s, [int max = 240]) {
  final clean = s.replaceAll(RegExp(r"\s+"), ' ').trim();
  return clean.length <= max ? clean : clean.substring(0, max) + '…';
}

Future<bool> _checkGemini() async {
  final key = Platform.environment['GEMINI_API_KEY'];
  final model = Platform.environment['GEMINI_MODEL'] ?? 'gemini-1.5-flash-latest';
  if (key == null || key.isEmpty) {
    stdout.writeln('Gemini: GEMINI_API_KEY is missing');
    return false;
  }
  final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$key');
  final body = {
    'contents': [
      {
        'parts': [
          {'text': 'Ping from AI sanity checker. Reply with a short hello.'}
        ]
      }
    ]
  };
  final res = await _postJson(uri, {'Content-Type': 'application/json'}, body);
  stdout.writeln('Gemini [$model]: HTTP ${res.status} in ${res.elapsed.inMilliseconds}ms');
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = j['candidates'] as List<dynamic>?;
    final text = candidates != null && candidates.isNotEmpty
        ? ((candidates.first as Map)['content']?['parts']?[0]?['text'] as String? ?? '')
        : (j['error']?['message'] as String? ?? '');
    stdout.writeln('Gemini text: ${_truncate(text)}');
    return res.status == 200 && text.isNotEmpty;
  } catch (_) {
    stdout.writeln('Gemini raw: ${_truncate(res.body)}');
    return false;
  }
}

Future<bool> _checkOpenAI() async {
  final key = Platform.environment['OPENAI_API_KEY'] ?? Platform.environment['OPENAI_KEY'];
  final base = Platform.environment['OPENAI_BASE_URL']?.trim().isNotEmpty == true
      ? Platform.environment['OPENAI_BASE_URL']!.trim().replaceAll(RegExp(r"/+$"), '')
      : 'https://api.openai.com/v1';
  final model = Platform.environment['OPENAI_MODEL'] ?? 'gpt-4o-mini';
  if (key == null || key.isEmpty) {
    stdout.writeln('OpenAI: OPENAI_API_KEY/OPENAI_KEY is missing');
    return false;
  }
  final uri = Uri.parse('$base/chat/completions');
  final body = {
    'model': model,
    'temperature': 0.2,
    'max_tokens': 64,
    'messages': [
      {'role': 'system', 'content': 'You are a helpful assistant.'},
      {'role': 'user', 'content': 'Ping from AI sanity checker. Short hello, please.'}
    ]
  };
  final res = await _postJson(
      uri, {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'}, body);
  stdout.writeln('OpenAI [$model]: HTTP ${res.status} in ${res.elapsed.inMilliseconds}ms');
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = j['choices'] as List<dynamic>?;
    final text = choices != null && choices.isNotEmpty
        ? ((choices.first as Map)['message']?['content'] as String? ?? '')
        : (j['error']?['message'] as String? ?? '');
    stdout.writeln('OpenAI text: ${_truncate(text)}');
    return res.status == 200 && text.isNotEmpty;
  } catch (_) {
    stdout.writeln('OpenAI raw: ${_truncate(res.body)}');
    return false;
  }
}

Future<void> main() async {
  stdout.writeln('AI Sanity Check\n================');
  final g = await _checkGemini();
  final o = await _checkOpenAI();
  final ok = g && o;
  stdout.writeln('\nResult: ${ok ? 'OK' : 'FAILED'}');
  exit(ok ? 0 : 1);
}
