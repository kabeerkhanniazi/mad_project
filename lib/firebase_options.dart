// Firebase keys for this app.
//
// This file is written by `dart run tool/gen_firebase_options.dart` from the
// files downloaded in the Firebase console. While `isConfigured` is false the
// app runs in demo mode and stores nothing in the cloud.
//
// These values identify the Firebase project; they are not passwords.
// Access to data is controlled by firestore.rules.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class DefaultFirebaseOptions {
  static const isConfigured = false;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return android;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ios,
      _ => android,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'fitness-and-habit-tracker',
  );

  static const ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'fitness-and-habit-tracker',
    iosBundleId: 'com.kabeerkhanniazi.fithabit',
  );
}
