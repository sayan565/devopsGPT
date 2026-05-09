// File generated manually from Firebase console config
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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
    apiKey: 'AIzaSyD33E6FkTcGXe5t69pKIk30OyYhvIUqSE0',
    authDomain: 'devopsgpt-bfb52.firebaseapp.com',
    projectId: 'devopsgpt-bfb52',
    storageBucket: 'devopsgpt-bfb52.firebasestorage.app',
    messagingSenderId: '1063250830043',
    appId: '1:1063250830043:web:7f5d1fa8f6ce7a4627e2fe',
  );

  // Use same config for Android & Windows until you add those platforms
  static const FirebaseOptions android = web;
  static const FirebaseOptions windows = web;
}
