import 'package:flutter/material.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _FaqItem(
            question: 'How do I generate a meal plan?',
            answer: 'Go to Meal Plans, choose a timeframe (daily/weekly), and tap Generate. You can save and access offline.',
          ),
          _FaqItem(
            question: 'How does offline mode work?',
            answer: 'Enable Offline Mode in Settings > Offline & Accessibility, then download tips/meal plans. The app will auto-sync when back online.',
          ),
          _FaqItem(
            question: 'How do I reset my password?',
            answer: 'On the Sign in screen, tap Forgot Password and follow the steps to receive a reset email.',
          ),
          _FaqItem(
            question: 'How can I contact support?',
            answer: 'Use the Send Feedback option in Settings to email us, or visit Help & FAQ for common questions.',
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(answer),
          ],
        ),
      ),
    );
  }
}
