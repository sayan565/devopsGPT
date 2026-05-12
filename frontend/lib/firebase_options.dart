// Firebase configuration — all values injected via --dart-define at build time.
// IMPORTANT: No real credentials appear in this file.
// defaultValue is intentionally empty — the app will not initialise Firebase
// unless the correct values are supplied at build time via --dart-define.
//
// Build command:
//   flutter run \
//     --dart-define=FIREBASE_API_KEY=xxx \
//     --dart-define=FIREBASE_AUTH_DOMAIN=xxx \
//     --dart-define=FIREBASE_PROJECT_ID=xxx \
//     --dart-define=FIREBASE_STORAGE_BUCKET=xxx \
//     --dart-define=FIREBASE_MESSAGING_SENDER_ID=xxx \
//     --dart-define=FIREBASE_APP_ID=xxx
//
// For local development, copy .env.example to .env and use a build script
// that reads from .env and passes --dart-define flags automatically.
//
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  // Set via --dart-define=FIREBASE_API_KEY=xxx at build time
  // defaultValue is empty — real value must be supplied at build time
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');

  // Set via --dart-define=FIREBASE_AUTH_DOMAIN=xxx at build time
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  // Set via --dart-define=FIREBASE_PROJECT_ID=xxx at build time
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  // Set via --dart-define=FIREBASE_STORAGE_BUCKET=xxx at build time
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  // Set via --dart-define=FIREBASE_MESSAGING_SENDER_ID=xxx at build time
  static const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  // Set via --dart-define=FIREBASE_APP_ID=xxx at build time
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            _apiKey,
    authDomain:        _authDomain,
    projectId:         _projectId,
    storageBucket:     _storageBucket,
    messagingSenderId: _messagingSenderId,
    appId:             _appId,
  );

  // Use same config for Android & Windows until platform-specific configs added
  static const FirebaseOptions android = web;
  static const FirebaseOptions windows = web;
}
