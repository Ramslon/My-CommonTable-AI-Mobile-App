import 'package:flutter/material.dart';
import 'package:commontable_ai_app/core/services/health_sync_service.dart';
import 'package:commontable_ai_app/core/services/fitbit_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class HealthSyncSettingsScreen extends StatefulWidget {
  const HealthSyncSettingsScreen({super.key});

  @override
  State<HealthSyncSettingsScreen> createState() => _HealthSyncSettingsScreenState();
}

class _HealthSyncSettingsScreenState extends State<HealthSyncSettingsScreen> {
  final _health = HealthSyncService();
  final _fitbit = FitbitService();
  bool _connecting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    // Show current Fitbit connection status on load
    _fitbit.isConnected().then((ok) {
      if (!mounted) return;
      if (ok) setState(() => _status = 'Fitbit connected');
    });
  }

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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    setState(() => _status = 'Starting Fitbit sign-in…');
                    final msg = await _fitbit.authorize();
                    if (!mounted) return;
                    setState(() => _status = msg);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _status = 'Fitbit auth failed: $e');
                  }
                },
                icon: const Icon(Icons.watch),
                label: const Text('Connect Fitbit (OAuth)'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        setState(() => _status = 'Fetching Fitbit profile…');
                        final profile = await _fitbit.getProfile();
                        if (!mounted) return;
                        final user = (profile['user'] as Map?) ?? {};
                        final name = user['displayName'] ?? user['fullName'] ?? 'Unknown';
                        setState(() => _status = 'Fitbit profile: $name');
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _status = 'Profile failed: $e');
                      }
                    },
                    icon: const Icon(Icons.account_circle),
                    label: const Text('View Fitbit profile'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await _fitbit.disconnect();
                      if (!mounted) return;
                      setState(() => _status = 'Disconnected Fitbit');
                    },
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.favorite),
                  label: const Text('Open Google Fit'),
                  onPressed: Platform.isAndroid ? _openGoogleFit : null,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Open Apple Health'),
                  onPressed: Platform.isIOS ? _openAppleHealth : null,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.watch),
                  label: const Text('Fitbit'),
                  onPressed: _openFitbit,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.directions_bike),
                  label: const Text('Garmin'),
                  onPressed: _openGarmin,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.scale),
                  label: const Text('Withings'),
                  onPressed: _openWithings,
                ),
              ],
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

  Future<void> _openUrlList(List<Uri> candidates) async {
    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open target app or store.')));
  }

  Future<void> _openGoogleFit() async {
    // Try intent to app, then Play Store fallback
    await _openUrlList([
      Uri.parse('intent://open#Intent;scheme=googlefit;package=com.google.android.apps.fitness;end'),
      Uri.parse('market://details?id=com.google.android.apps.fitness'),
      Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.fitness'),
    ]);
  }

  Future<void> _openAppleHealth() async {
    // Health is built-in; scheme should open app on iOS
    await _openUrlList([
      Uri.parse('x-apple-health://'),
      Uri.parse('x-apple-health://sources'),
    ]);
  }

  Future<void> _openFitbit() async {
    await _openUrlList([
      Uri.parse('fitbit://'),
      if (Platform.isAndroid) Uri.parse('market://details?id=com.fitbit.FitbitMobile') else Uri.parse('https://apps.apple.com/app/fitbit-health-fitness/id462638897'),
      Uri.parse('https://www.fitbit.com/'),
    ]);
  }

  Future<void> _openGarmin() async {
    await _openUrlList([
      Uri.parse('garminconnect://'),
      if (Platform.isAndroid) Uri.parse('market://details?id=com.garmin.android.apps.connectmobile') else Uri.parse('https://apps.apple.com/app/garmin-connect/id583446403'),
      Uri.parse('https://connect.garmin.com/'),
    ]);
  }

  Future<void> _openWithings() async {
    await _openUrlList([
      Uri.parse('withings-health-mate://'),
      if (Platform.isAndroid) Uri.parse('market://details?id=com.withings.wiscale2') else Uri.parse('https://apps.apple.com/app/withings-health-mate/id542701020'),
      Uri.parse('https://www.withings.com/health-mate'),
    ]);
  }
}
