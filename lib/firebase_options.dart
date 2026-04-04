// File generated manually from google-services.json
// DO NOT modify api keys or project credentials

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA-CsHOxWZj7MI0T3Xk4s6xVOUKgSRwYNU',
    appId: '1:27198060531:web:astra_web',
    messagingSenderId: '27198060531',
    projectId: 'astra-94fe7',
    authDomain: 'astra-94fe7.firebaseapp.com',
    storageBucket: 'astra-94fe7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-CsHOxWZj7MI0T3Xk4s6xVOUKgSRwYNU',
    appId: '1:27198060531:android:dd3421bf0f90e420be8486',
    messagingSenderId: '27198060531',
    projectId: 'astra-94fe7',
    storageBucket: 'astra-94fe7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA-CsHOxWZj7MI0T3Xk4s6xVOUKgSRwYNU',
    appId: '1:27198060531:ios:astra_ios',
    messagingSenderId: '27198060531',
    projectId: 'astra-94fe7',
    storageBucket: 'astra-94fe7.firebasestorage.app',
    iosBundleId: 'com.astra.astra',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA-CsHOxWZj7MI0T3Xk4s6xVOUKgSRwYNU',
    appId: '1:27198060531:web:astra_windows',
    messagingSenderId: '27198060531',
    projectId: 'astra-94fe7',
    authDomain: 'astra-94fe7.firebaseapp.com',
    storageBucket: 'astra-94fe7.firebasestorage.app',
  );
}
