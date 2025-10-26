import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 20),
            _buildSettingsSection(
              title: 'Profile',
              children: [
                _buildSettingsTile(
                  icon: Icons.person,
                  title: 'Account Information',
                  subtitle: 'Manage your profile details',
                  onTap: () {
                    // TODO: Navigate to account info
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Manage app notifications',
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSettingsSection(
              title: 'App Preferences',
              children: [
                _buildSettingsTile(
                  icon: Icons.palette,
                  title: 'Theme',
                  subtitle: 'Customize app appearance',
                  onTap: () {
                    // TODO: Navigate to theme settings
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'Change app language',
                  onTap: () {
                    // TODO: Navigate to language settings
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSettingsSection(
              title: 'Support',
              children: [
                _buildSettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & FAQ',
                  subtitle: 'Get help and support',
                  onTap: () {
                    // TODO: Navigate to help
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.feedback,
                  title: 'Send Feedback',
                  subtitle: 'Share your thoughts',
                  onTap: () {
                    // TODO: Navigate to feedback
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
