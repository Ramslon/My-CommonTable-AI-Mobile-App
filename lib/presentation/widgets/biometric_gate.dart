import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';

class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _unlocked = true; // default true until we know it's enabled
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    if (kReleaseMode) {
      _check();
    } else {
      // In debug/test builds, don't block initial UI to keep tests/dev flow simple.
      _unlocked = true;
      _checking = false;
    }
  }

  Future<void> _check() async {
    final settings = await PrivacySettingsService().load();
    if (!settings.biometricLockEnabled) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }
    final auth = LocalAuthentication();
    final available = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    if (!available) {
      setState(() {
        _unlocked = true; // fail-open to avoid lockout if hardware missing
        _checking = false;
      });
      return;
    }
    final ok = await auth.authenticate(
      localizedReason: 'Unlock Commontable AI',
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Material(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_unlocked) return widget.child;
    return Material(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64),
          const SizedBox(height: 12),
          const Text('Locked', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Unlock with biometrics'),
          ),
        ],
      ),
    );
  }
}
