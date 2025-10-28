import 'package:flutter/material.dart';
import 'package:commontable_ai_app/core/services/app_settings.dart';
import 'package:commontable_ai_app/core/services/auth_service.dart';
import 'package:commontable_ai_app/routes/app_route.dart';
import 'package:commontable_ai_app/core/services/nutrition_insights_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  InsightsProvider _provider = InsightsProvider.simulated;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final setting = await AppSettings().getInsightsProvider();
    if (mounted) setState(() => _provider = setting);
  }

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
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                ),
                _buildSettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy & Security',
                  subtitle: 'Biometrics, data usage, export & deletion',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.privacySettings),
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
                ListTile(
                  leading: Icon(
                    Icons.auto_awesome,
                    color: Colors.grey.shade600,
                  ),
                  title: const Text('AI Insights Provider'),
                  subtitle: Text(_labelForProvider(_provider)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _chooseProvider,
                ),
                _buildSettingsTile(
                  icon: Icons.offline_bolt,
                  title: 'Offline & Accessibility',
                  subtitle: 'Download data, text size, voice logging',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.offlineAccessibility),
                ),
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
                  icon: Icons.logout,
                  title: 'Sign out',
                  subtitle: 'Sign out of your account',
                  onTap: () async {
                    try {
                      await AuthService().signOut();
                    } catch (_) {}
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.auth, (r) => false);
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.balance_outlined,
                  title: 'AI Bias & Fairness',
                  subtitle: 'How we ensure inclusive, culturally-aware guidance',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.aiBiasFairness),
                ),
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

  String _labelForProvider(InsightsProvider p) {
    return switch (p) {
      InsightsProvider.simulated => 'Simulated (offline)',
      InsightsProvider.gemini => 'Gemini (requires API key)',
      InsightsProvider.huggingFace => 'Hugging Face (requires API key)',
    };
  }

  Future<void> _chooseProvider() async {
    final selected = await showModalBottomSheet<InsightsProvider>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        var temp = _provider;
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select AI Insights Provider',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _ProviderOption(
                    title: 'Simulated (offline demo)',
                    selected: temp == InsightsProvider.simulated,
                    onTap: () =>
                        setModal(() => temp = InsightsProvider.simulated),
                  ),
                  _ProviderOption(
                    title: 'Gemini (Google AI)',
                    subtitle: 'Requires GEMINI_API_KEY at build/run',
                    selected: temp == InsightsProvider.gemini,
                    onTap: () => setModal(() => temp = InsightsProvider.gemini),
                  ),
                  _ProviderOption(
                    title: 'Hugging Face Inference API',
                    subtitle: 'Requires HF_API_KEY at build/run',
                    selected: temp == InsightsProvider.huggingFace,
                    onTap: () =>
                        setModal(() => temp = InsightsProvider.huggingFace),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, temp),
                      child: const Text('Use Provider'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      await AppSettings().setInsightsProvider(selected);
      if (!mounted) return;
      setState(() => _provider = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI provider set to ${_labelForProvider(selected)}'),
        ),
      );
    }
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

class _ProviderOption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderOption({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: onTap,
    );
  }
}
