import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Initializes Firebase safely and exposes availability.
///
/// This allows the app to boot in "local-only" mode when Firebase
/// configuration is missing (e.g., no google-services.json / plist).
class FirebaseBoot {
  static bool available = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
    } catch (_) {
      available = false;
      return;
    }

    // Ensure a user for per-user scoping; ignore failures silently.
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }
}
