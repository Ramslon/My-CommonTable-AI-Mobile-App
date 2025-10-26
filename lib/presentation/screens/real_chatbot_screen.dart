import 'package:flutter/material.dart';

class RealChatbotScreen extends StatefulWidget {
  const RealChatbotScreen({super.key});

  @override
  State<RealChatbotScreen> createState() => _RealChatbotScreenState();
}

class _RealChatbotScreenState extends State<RealChatbotScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isTyping = true;
      _controller.clear();
    });

    // Simulated AI response (replace with API integration later)
    await Future.delayed(const Duration(seconds: 2));
    String aiResponse = _generateMockResponse(text);

    setState(() {
      _messages.add({'text': aiResponse, 'isUser': false});
      _isTyping = false;
    });
  }

  String _generateMockResponse(String userInput) {
    userInput = userInput.toLowerCase();
    if (userInput.contains('protein')) {
      return "High-protein foods include chicken breast, eggs, tofu, and lentils. Aim for about 1.6–2.2g of protein per kg of body weight.";
    } else if (userInput.contains('breakfast')) {
      return "Try oatmeal with fruits and nuts — rich in fiber, protein, and slow-digesting carbs to keep you energized!";
    } else if (userInput.contains('water')) {
      return "Great reminder! Drinking enough water supports digestion and metabolism — aim for about 2 to 3 liters daily.";
    } else {
      return "I’m your AI nutrition coach 🤖. Ask me about healthy meals, calorie info, or fitness nutrition tips!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Nutrition Chatbot"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message['isUser']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: message['isUser']
                          ? Colors.green.shade200
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message['text'],
                      style: const TextStyle(fontSize: 15),
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
              child: Text("AI is typing...", style: TextStyle(color: Colors.grey)),
            ),

          // Input field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Ask me about nutrition...",
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