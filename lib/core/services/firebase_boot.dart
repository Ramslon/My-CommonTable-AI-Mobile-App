import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:commontable_ai_app/firebase_options.dart';

/// Initializes Firebase safely and exposes availability.
///
/// This allows the app to boot in "local-only" mode when Firebase
/// configuration is missing (e.g., no google-services.json / plist).
class FirebaseBoot {
  static bool available = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      available = true;
    } catch (_) {
      available = false;
      return;
    }

    // Enable offline persistence where possible to improve resiliency on
    // flaky or restricted networks. This allows reads from cache when DNS
    // resolution temporarily fails and reduces log noise from transient errors.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (_) {}
    try {
      // Safe if called multiple times; ignored on web
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    } catch (_) {}

    // Set a default language to avoid null locale headers and ensure consistent
    // verification messages (e.g., password reset emails).
    try {
      await FirebaseAuth.instance.setLanguageCode('en');
    } catch (_) {}

    // Ensure a user for per-user scoping; ignore failures silently.
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }
}
