import 'package:flutter/material.dart';
import 'package:commontable_ai_app/core/services/health_sync_service.dart';

class HealthSyncSettingsScreen extends StatefulWidget {
  const HealthSyncSettingsScreen({super.key});

  @override
  State<HealthSyncSettingsScreen> createState() => _HealthSyncSettingsScreenState();
}

class _HealthSyncSettingsScreenState extends State<HealthSyncSettingsScreen> {
  final _health = HealthSyncService();
  bool _connecting = false;
  String? _status;

  Future<void> _connect() async {
    setState(() { _connecting = true; _status = null; });
    try {
      // Placeholder connect: attempt a pull to trigger permissions/availability
      final data = await _health.pullNutrition();
      setState(() {
        _status = data.isEmpty
            ? 'Connected. No recent nutrition data found yet.'
            : 'Connected. Sample keys: ${data.keys.take(3).join(', ')}';
      });
    } catch (e) {
      setState(() { _status = 'Connection failed: $e'; });
    } finally {
      if (mounted) setState(() { _connecting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Sync Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connect your devices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sync with your CGM, smart scale, wearables, and fitness apps to power precise, real-time nutrition insights.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: const Icon(Icons.link),
                label: Text(_connecting ? 'Connecting…' : 'Connect devices'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!),
            ],
            const SizedBox(height: 24),
            const Text('Supported (examples): • Google Fit • Apple HealthKit • Garmin • Fitbit • Withings'),
          ],
        ),
      ),
    );
  }
}
