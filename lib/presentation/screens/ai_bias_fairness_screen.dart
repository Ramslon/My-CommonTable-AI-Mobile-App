import 'package:flutter/material.dart';
import 'package:commontable_ai_app/presentation/screens/legal_markdown_viewer.dart';

class AIBiasFairnessScreen extends StatelessWidget {
  const AIBiasFairnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalMarkdownViewer(
      title: 'AI Bias & Fairness',
      assetPath: 'assets/legal/ai_bias_fairness.md',
    );
  }
}
