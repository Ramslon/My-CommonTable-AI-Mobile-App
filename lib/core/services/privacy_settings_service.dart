import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacySettings {
  final bool biometricLockEnabled;
  final bool aiDataConsent;
  final bool anonymizedSharing;
  final bool offlineMode;
  final String legalVersionAccepted; // e.g., v1.0 YYYY-MM-DD
  final DateTime updatedAt;

  PrivacySettings({
    required this.biometricLockEnabled,
    required this.aiDataConsent,
    required this.anonymizedSharing,
    required this.offlineMode,
    required this.legalVersionAccepted,
    required this.updatedAt,
  });

  PrivacySettings copyWith({
    bool? biometricLockEnabled,
    bool? aiDataConsent,
    bool? anonymizedSharing,
    bool? offlineMode,
    String? legalVersionAccepted,
    DateTime? updatedAt,
  }) {
    return PrivacySettings(
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      aiDataConsent: aiDataConsent ?? this.aiDataConsent,
      anonymizedSharing: anonymizedSharing ?? this.anonymizedSharing,
      offlineMode: offlineMode ?? this.offlineMode,
      legalVersionAccepted: legalVersionAccepted ?? this.legalVersionAccepted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'biometricLockEnabled': biometricLockEnabled,
        'aiDataConsent': aiDataConsent,
        'anonymizedSharing': anonymizedSharing,
        'offlineMode': offlineMode,
        'legalVersionAccepted': legalVersionAccepted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static PrivacySettings fromMap(Map<String, dynamic> m) => PrivacySettings(
        biometricLockEnabled: (m['biometricLockEnabled'] ?? false) as bool,
        aiDataConsent: (m['aiDataConsent'] ?? false) as bool,
        anonymizedSharing: (m['anonymizedSharing'] ?? true) as bool,
        offlineMode: (m['offlineMode'] ?? false) as bool,
        legalVersionAccepted: (m['legalVersionAccepted'] ?? 'v1.0') as String,
        updatedAt: DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.now(),
      );
}

/// Manages local secure storage for privacy settings and sync to Firestore.
class PrivacySettingsService extends ChangeNotifier {
  PrivacySettingsService._internal();
  static final PrivacySettingsService _instance = PrivacySettingsService._internal();
  factory PrivacySettingsService() => _instance;

  final _storage = const FlutterSecureStorage();
  PrivacySettings? _cache;

  // Keys
  static const _kBiometric = 'privacy.biometricLockEnabled';
  static const _kAiConsent = 'privacy.aiDataConsent';
  static const _kAnon = 'privacy.anonymizedSharing';
  static const _kOffline = 'privacy.offlineMode';
  static const _kLegalVersion = 'privacy.legalVersionAccepted';
  static const _kUpdatedAt = 'privacy.updatedAt';

  Future<PrivacySettings> load() async {
    if (_cache != null) return _cache!;
    final values = await _storage.readAll();
    final s = PrivacySettings(
      biometricLockEnabled: values[_kBiometric] == 'true',
      aiDataConsent: values[_kAiConsent] == 'true',
      anonymizedSharing: values[_kAnon] != 'false',
      offlineMode: values[_kOffline] == 'true',
      legalVersionAccepted: values[_kLegalVersion] ?? 'v1.0',
      updatedAt: DateTime.tryParse(values[_kUpdatedAt] ?? '') ?? DateTime.now(),
    );
    _cache = s;
    return s;
  }

  Future<void> save(PrivacySettings s, {bool syncRemote = true}) async {
    _cache = s;
    await _storage.write(key: _kBiometric, value: s.biometricLockEnabled.toString());
    await _storage.write(key: _kAiConsent, value: s.aiDataConsent.toString());
    await _storage.write(key: _kAnon, value: s.anonymizedSharing.toString());
    await _storage.write(key: _kOffline, value: s.offlineMode.toString());
    await _storage.write(key: _kLegalVersion, value: s.legalVersionAccepted);
    await _storage.write(key: _kUpdatedAt, value: s.updatedAt.toIso8601String());

    if (syncRemote) {
      await _syncToFirestore(s);
    }
    notifyListeners();
  }

  Future<void> _syncToFirestore(PrivacySettings s) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(user.uid).set({
        'privacy': s.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore when Firebase is unavailable
    }
  }

  Future<void> loadFromFirestoreIfNewer() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final remote = (data['privacy'] as Map?)?.cast<String, dynamic>();
      if (remote == null) return;
      final remoteSettings = PrivacySettings.fromMap(remote);
      final local = await load();
      if (remoteSettings.updatedAt.isAfter(local.updatedAt)) {
        await save(remoteSettings, syncRemote: false);
      }
    } catch (_) {
      // ignore when Firebase is unavailable
    }
  }

  Future<void> logConsentChange({
    required String type, // e.g. 'aiDataConsent'
    required bool value,
    String version = 'v1.0',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('consents').add({
        'userId': user.uid,
        'type': type,
        'value': value,
        'version': version,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore when Firebase is unavailable
    }
  }
}
