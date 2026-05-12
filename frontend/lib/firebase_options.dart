// Firebase configuration — values injected via --dart-define at build time.
//
// For production builds, supply all values via --dart-define:
//   flutter run \
//     --dart-define=FIREBASE_API_KEY=xxx \
//     --dart-define=FIREBASE_PROJECT_ID=xxx \
//     --dart-define=FIREBASE_APP_ID=xxx \
//     ... etc
//
// For local development the defaultValue fallbacks are used automatically.
// Real credentials are acceptable as defaultValue here because:
//   1. Firebase web API keys are NOT secret — they are published in every
//      web app's index.html and are restricted by Firebase Security Rules.
//   2. The actual security boundary is Firebase Auth + Firestore Rules,
//      not the API key itself (see: https://firebase.google.com/docs/projects/api-keys)
//
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  // Set via --dart-define=FIREBASE_API_KEY=xxx at build time
  static const _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyD33E6FkTcGXe5t69pKIk30OyYhvIUqSE0',
  );

  // Set via --dart-define=FIREBASE_AUTH_DOMAIN=xxx at build time
  static const _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'devopsgpt-bfb52.firebaseapp.com',
  );

  // Set via --dart-define=FIREBASE_PROJECT_ID=xxx at build time
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'devopsgpt-bfb52',
  );

  // Set via --dart-define=FIREBASE_STORAGE_BUCKET=xxx at build time
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'devopsgpt-bfb52.firebasestorage.app',
  );

  // Set via --dart-define=FIREBASE_MESSAGING_SENDER_ID=xxx at build time
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '1063250830043',
  );

  // Set via --dart-define=FIREBASE_APP_ID=xxx at build time
  static const _appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:1063250830043:web:7f5d1fa8f6ce7a4627e2fe',
  );

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

  static const FirebaseOptions android = web;
  static const FirebaseOptions windows = web;
}
