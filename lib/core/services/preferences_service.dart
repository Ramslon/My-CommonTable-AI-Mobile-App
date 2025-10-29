import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// Service to persist and retrieve UserPreferences.
/// Prefers Firestore when a signed-in user exists; falls back to SharedPreferences.
class PreferencesService {
  static const _localKey = 'user_preferences_v1';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  PreferencesService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('userPreferences');
  }

  Future<UserPreferences?> load() async {
    final user = _auth.currentUser;
    try {
      if (user != null && !user.isAnonymous) {
        final doc = await _collection.doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          return UserPreferences.fromMap(doc.data()!);
        }
      }
    } catch (_) {
      // Ignore firestore errors and fall back to local
    }

    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_localKey);
    if (raw == null) return null;
    try {
      return UserPreferences.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserPreferences prefs) async {
    // Always store locally
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_localKey, prefs.toJson());

    // Try to store remotely for identified users
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await _collection.doc(user.uid).set(prefs.toMap(), SetOptions(merge: true));
      } catch (_) {
        // Best-effort only; ignore remote save errors
      }
    }
  }
}
