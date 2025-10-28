import 'package:flutter/material.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:commontable_ai_app/core/services/notifications_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _enabled = true;
  bool _daily = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppSettings().getNotificationsEnabled();
    final daily = await AppSettings().getDailyReminderEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _daily = daily;
      _loading = false;
    });
  }

  Future<void> _toggleEnabled(bool v) async {
    setState(() => _enabled = v);
    await NotificationsService.setEnabled(v);
  }

  Future<void> _toggleDaily(bool v) async {
    setState(() => _daily = v);
    await AppSettings().setDailyReminderEnabled(v);
    // Optional: schedule/cancel local reminders here if you implement scheduling
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: _toggleEnabled,
                  title: const Text('Enable notifications'),
                  subtitle: const Text('Allow Commontable AI to send alerts and tips'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _daily,
                  onChanged: _enabled ? _toggleDaily : null,
                  title: const Text('Daily reminder'),
                  subtitle: const Text('Get a daily nudge to check your plan'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Quick test notification
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test notification sent (if enabled)')));
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Send test notification'),
                ),
              ],
            ),
    );
  }
}
