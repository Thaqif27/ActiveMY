import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA96mTnnPgKaogR3A9F3jNiZHKBvz9RBEE',
    appId: '1:564042764503:web:e3f5c9a463e0e7d53de092',
    messagingSenderId: '564042764503',
    projectId: 'activemy-a6bf1',
    authDomain: 'activemy-a6bf1.firebaseapp.com',
    databaseURL: 'https://activemy-a6bf1-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'activemy-a6bf1.firebasestorage.app',
    measurementId: 'G-HYR096K798',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAN9_4YfVSInxxwJ3HTpdHalDTPpK4MflU',
    appId: '1:564042764503:android:387f1b2e0c4d53df3de092',
    messagingSenderId: '564042764503',
    projectId: 'activemy-a6bf1',
    databaseURL: 'https://activemy-a6bf1-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'activemy-a6bf1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyApiKeyIOS_ActiveMY',
    appId: '1:1234567890:ios:1234567890abcdef',
    messagingSenderId: '1234567890',
    projectId: 'activemy-a6bf1',
    storageBucket: 'activemy-a6bf1.appspot.com',
    iosBundleId: 'com.activemy.app',
  );
}