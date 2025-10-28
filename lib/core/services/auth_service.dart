import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool _isAvailable() {
    // Prefer the boot flag; fall back to checking apps list.
    try {
      if (FirebaseBoot.available) return true;
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<User?> get authStateChanges {
    if (!_isAvailable()) {
      // When Firebase isn't configured, expose an empty stream with null user.
      return Stream<User?>.value(null);
    }
    return _auth.authStateChanges();
  }

  Future<UserCredential> registerWithEmail({required String email, required String password}) async {
    if (!_isAvailable()) {
      throw Exception('Authentication is not configured on this device');
    }
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithEmail({required String email, required String password}) async {
    if (!_isAvailable()) {
      throw Exception('Authentication is not configured on this device');
    }
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!_isAvailable()) {
      throw Exception('Authentication is not configured on this device');
    }
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Sign-in aborted');
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!_isAvailable()) return;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isAvailable()) {
      throw Exception('Authentication is not configured on this device');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  bool get isSignedIn {
    if (!_isAvailable()) return false;
    return _auth.currentUser != null && !(_auth.currentUser?.isAnonymous ?? false);
  }

  /// Ensure an anonymous session exists (or reuse current user).
  Future<User> ensureAnonymous() async {
    if (!_isAvailable()) {
      throw Exception('Authentication is not configured on this device');
    }
    final cur = _auth.currentUser;
    if (cur != null) return cur;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }
}
