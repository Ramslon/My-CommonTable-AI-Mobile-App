import 'package:flutter/material.dart';

class PremiumDevicesInfoScreen extends StatelessWidget {
  const PremiumDevicesInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Device Integrations')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Integration with Premium Health Devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Sync CGMs, smart scales, wearables, and advanced trackers to power precise nutrition tracking and adaptive coaching. '
              'Support includes glucose trends, body composition, heart rate variability, and more.',
            ),
          ],
        ),
      ),
    );
  }
}
