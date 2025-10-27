import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';
import 'package:commontable_ai_app/core/services/data_export_service.dart';
import 'package:commontable_ai_app/core/services/account_service.dart';
import 'package:commontable_ai_app/presentation/screens/legal_markdown_viewer.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _service = PrivacySettingsService();
  final _auth = FirebaseAuth.instance;
  PrivacySettings? _s;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Ensure we have a user (anonymous allowed)
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    await _service.loadFromFirestoreIfNewer();
    final s = await _service.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
  }

  Future<void> _update(PrivacySettings s, {String? consentType, bool? value}) async {
    setState(() => _s = s);
    await _service.save(s);
    if (consentType != null && value != null) {
      await _service.logConsentChange(type: consentType, value: value);
    }
  }

  Future<void> _toggleBiometrics(bool next) async {
    final auth = LocalAuthentication();
    bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    if (!canCheck) {
      _showSnack('Biometric authentication is not available on this device.');
      return;
    }
    if (next) {
      final ok = await auth.authenticate(
        localizedReason: 'Enable biometric lock for secure access',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return;
    }
    await _update(_s!.copyWith(
      biometricLockEnabled: next,
      updatedAt: DateTime.now(),
    ));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy, Security & Legal'),
      ),
      body: _loading || _s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  'Security',
                  [
                    SwitchListTile(
                      value: _s!.biometricLockEnabled,
                      onChanged: (v) => _toggleBiometrics(v),
                      title: const Text('Biometric authentication'),
                      subtitle: const Text('Require Face ID / Touch ID / fingerprint to open the app'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  'Data & AI usage',
                  [
                    SwitchListTile(
                      value: _s!.aiDataConsent,
                      onChanged: (v) => _update(_s!.copyWith(aiDataConsent: v, updatedAt: DateTime.now()),
                          consentType: 'aiDataConsent', value: v),
                      title: const Text('Allow AI to use my data for insights'),
                      subtitle: const Text('Your content helps generate personalized recommendations'),
                    ),
                    SwitchListTile(
                      value: _s!.anonymizedSharing,
                      onChanged: (v) => _update(_s!.copyWith(anonymizedSharing: v, updatedAt: DateTime.now()),
                          consentType: 'anonymizedSharing', value: v),
                      title: const Text('Allow anonymized, aggregated analytics'),
                      subtitle: const Text('We never sell personal data; analytics helps improve the product'),
                    ),
                    SwitchListTile(
                      value: _s!.offlineMode,
                      onChanged: (v) => _update(_s!.copyWith(offlineMode: v, updatedAt: DateTime.now())),
                      title: const Text('Offline mode'),
                      subtitle: const Text('Limit network calls where possible; some features may be reduced'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  'Legal transparency',
                  [
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalMarkdownViewer(
                            title: 'Privacy Policy',
                            assetPath: 'assets/legal/privacy_policy.md',
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalMarkdownViewer(
                            title: 'Terms of Service',
                            assetPath: 'assets/legal/terms.md',
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Encryption & Security Info'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalMarkdownViewer(
                            title: 'Encryption & Security',
                            assetPath: 'assets/legal/encryption_info.md',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  'Your rights',
                  [
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Download My Data'),
                      subtitle: const Text('Export a copy of your data (GDPR-ready)'),
                      onTap: () async {
                        try {
                          await DataExportService().exportMyDataAndShare();
                        } catch (e) {
                          _showSnack('Failed to export data');
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                      title: const Text('Delete My Account'),
                      subtitle: const Text('Permanently erase your data and account (GDPR/HIPAA)'),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm deletion'),
                            content: const Text(
                                'This will permanently delete your data and account. This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (!mounted) return;
                        if (confirm != true) return;
                        try {
                          await AccountService().deleteMyAccountAndData();
                          navigator.popUntil((r) => r.isFirst);
                          messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
                        } catch (e) {
                          _showSnack('Deletion failed. You might need to re-authenticate.');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Compliance-ready foundation: GDPR/HIPAA-aligned controls (consent logging, export/delete, minimization).',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        )
      ],
    );
  }
}
