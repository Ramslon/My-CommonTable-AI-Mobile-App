import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:commontable_ai_app/core/services/chat_coach_service.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';

class RealChatbotScreen extends StatefulWidget {
  const RealChatbotScreen({super.key});

  @override
  State<RealChatbotScreen> createState() => _RealChatbotScreenState();
}

class _RealChatbotScreenState extends State<RealChatbotScreen> {
  final List<_UiMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;
  bool _listening = false;
  String _providerLabel = 'Simulated';

  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  final _chat = ChatCoachService();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initProviderLabel();
    _seedGreeting();
  }

  Future<void> _initProviderLabel() async {
    final sel = await AppSettings().getInsightsProvider();
    // Map insights provider to chat label; auto-detect OpenAI when selection is simulated but key exists
    final auto = _chat.autoProvider;
    setState(() {
      switch (sel.name) {
        case 'gemini':
          _providerLabel = 'Gemini';
          break;
        case 'huggingFace':
          _providerLabel = 'Hugging Face';
          break;
        default:
          _providerLabel = auto == ChatProvider.openai
              ? 'OpenAI'
              : auto == ChatProvider.gemini
                  ? 'Gemini'
                  : auto == ChatProvider.huggingFace
                      ? 'Hugging Face'
                      : 'Simulated';
      }
    });
  }

  void _seedGreeting() {
    _messages.add(
      _UiMessage(
        text: 'Hi! I\'m your AI nutrition coach. Ask about breakfast ideas, mood-supportive foods, protein targets, or budget-friendly student meals.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(_UiMessage(text: trimmed, isUser: true));
      _isTyping = true;
      _controller.clear();
    });

    try {
      // Build last few turns for context
      final turns = _messages
          .map((m) => ChatTurn(role: m.isUser ? 'user' : 'assistant', content: m.text))
          .toList();
      final reply = await _chat.reply(history: turns);
      final parsed = _parseBullets(reply.text);
      setState(() {
        _messages.add(_UiMessage(text: parsed.base, isUser: false, tips: parsed.bullets));
      });
    } catch (e) {
      setState(() {
        _messages.add(_UiMessage(text: 'Sorry, I couldn\'t respond right now. ($e)', isUser: false));
      });
    } finally {
      setState(() => _isTyping = false);
    }
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(onStatus: (s) {
      if (s == 'notListening' && _listening) {
        setState(() => _listening = false);
      }
    }, onError: (e) {
      setState(() => _listening = false);
    });
    if (!available) return;
    setState(() => _listening = true);
    _speech.listen(
      onResult: (res) {
        if (!mounted) return;
        setState(() {
          _controller.text = res.recognizedWords;
          _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
        });
      },
      listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation, partialResults: true),
    );
  }

  Future<void> _speak(String text) async {
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  Future<void> _saveSuggestion(String text) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to save logs.')));
        return;
      }

      await FirebaseFirestore.instance.collection('chatNutritionLogs').add({
        'userId': user.uid,
        // Use server timestamp for consistent ordering/indexing; keep ISO for debug/export parity
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtIso': DateTime.now().toIso8601String(),
        'source': 'chat',
        'content': text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to nutrition log')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Nutrition Chatbot"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              label: Text('AI: $_providerLabel', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final align = m.isUser ? Alignment.centerRight : Alignment.centerLeft;
                final bg = m.isUser ? Colors.green.withValues(alpha: 0.18) : Colors.teal.withValues(alpha: 0.10);
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text, style: const TextStyle(fontSize: 15)),
                        if (m.tips != null && m.tips!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...m.tips!.map((t) => Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(t)),
                                ],
                              )),
                        ],
                        if (!m.isUser) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _speak(m.text),
                                icon: const Icon(Icons.volume_up),
                                label: const Text('Listen'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _saveSuggestion(m.text),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                label: const Text('Save'),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('AI is typing...', style: TextStyle(color: Colors.grey)),
            ),

          // Input field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleListen,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : Colors.grey.shade800),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask me about nutrition...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.green),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UiMessage {
  final String text;
  final bool isUser;
  final List<String>? tips; // future-friendly for rich replies
  const _UiMessage({required this.text, required this.isUser, this.tips});
}

class _ParsedReply {
  final String base;
  final List<String>? bullets;
  _ParsedReply(this.base, this.bullets);
}

_ParsedReply _parseBullets(String text) {
  final lines = text.split('\n');
  final bullets = <String>[];
  final baseLines = <String>[];
  for (final l in lines) {
    final t = l.trimLeft();
    if (t.startsWith('• ') || t.startsWith('- ')) {
      final cleaned = t.substring(2).trim();
      if (cleaned.isNotEmpty) bullets.add(cleaned);
    } else {
      baseLines.add(l);
    }
  }
  final base = baseLines.join('\n').trim();
  return _ParsedReply(base.isEmpty ? text : base, bullets.isEmpty ? null : bullets);
}