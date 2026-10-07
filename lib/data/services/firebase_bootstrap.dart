import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_demo_app/data/services/firebase_options.dart';

/// Initializes Firebase with the generated options for the current platform.
/// Authentication remains gated when initialization fails; the app never
/// falls through to an unauthenticated demo account.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return true;
    } on FirebaseException catch (error) {
      debugPrint('Firebase is not configured: ${error.code} ${error.message}');
      return false;
    } catch (error) {
      debugPrint('Firebase is not configured: $error');
      return false;
    }
  }
}
