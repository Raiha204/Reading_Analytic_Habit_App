import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'profile_preferences.dart';

class AuthService {
  // This is the Web OAuth client ID listed in google-services.json. Android
  // uses it as the server client ID to mint the ID token Firebase Auth needs.
  static const _googleServerClientId =
      '127986638245-et8ueqaot5v9kncj0rc7n24filkfetp0.apps.googleusercontent.com';
  static final _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInitialization;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String username,
    required String email,
    required String password,
    Uint8List? avatarBytes,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final cleanUsername = username.trim();
    if (avatarBytes != null) {
      await ProfilePreferences.instance.saveAvatar(
        credential.user!.uid,
        avatarBytes,
      );
    }
    await credential.user?.updateDisplayName(cleanUsername);
    await credential.user?.sendEmailVerification();
    await _saveProfileSafely(credential.user, name: cleanUsername);
    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final result = await _auth.signInWithPopup(GoogleAuthProvider());
      await _saveProfileSafely(result.user);
      return result;
    }
    await (_googleSignInInitialization ??= _googleSignIn.initialize(
      serverClientId: _googleServerClientId,
    ));
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an ID token. Check the Android SHA-1 and OAuth client configuration in Firebase.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    await _saveProfileSafely(result.user);
    return result;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null)
      throw StateError('Sign in before requesting verification.');
    await user.sendEmailVerification();
  }

  Future<void> refreshCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await (_googleSignInInitialization ??= _googleSignIn.initialize(
          serverClientId: _googleServerClientId,
        ));
        await _googleSignIn.signOut();
      } catch (error) {
        debugPrint('Google session cleanup failed: $error');
      }
    }
    await _auth.signOut();
  }

  Future<void> _saveProfile(User? user, {String? name}) async {
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': name ?? user.displayName ?? '',
      'username': name ?? user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveProfileSafely(User? user, {String? name}) async {
    try {
      await _saveProfile(user, name: name);
    } on FirebaseException catch (error) {
      debugPrint(
        'Firebase profile save failed: ${error.code} ${error.message}',
      );
    }
  }

  static bool isSignInCancelled(Object error) {
    if (error is FirebaseAuthException) {
      return const {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-cancelled',
      }.contains(error.code);
    }
    return error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled;
  }

  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'The email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'Use a stronger password with at least 6 characters.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'account-exists-with-different-credential':
          return 'This email is already linked to another sign-in method.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
      }
      return error.message ?? 'Authentication failed. Please try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
