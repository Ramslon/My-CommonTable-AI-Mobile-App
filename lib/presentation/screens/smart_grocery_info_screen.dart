import 'package:flutter/material.dart';

class SmartGroceryInfoScreen extends StatelessWidget {
  const SmartGroceryInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Grocery & Meal Delivery')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Personalized Meal Delivery & Smart Grocery Lists',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'We generate optimized weekly meal plans, then auto-sync grocery lists with supported delivery partners. '
              'Swap items, manage dietary constraints, and keep within your budget with dynamic recommendations.',
            ),
          ],
        ),
      ),
    );
  }
}
