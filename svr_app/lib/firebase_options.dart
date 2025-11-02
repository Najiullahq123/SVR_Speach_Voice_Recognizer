import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDNlNAt5Mkcv7LDszXWeNkI-YXnN1yEfDI',
    appId: '1:119820460667:web:c33765c5916c99e6f238de',
    messagingSenderId: '119820460667',
    projectId: 'svr-app-96763',
    authDomain: 'svr-app-96763.firebaseapp.com',
    databaseURL: 'https://svr-app-96763-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'svr-app-96763.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAXs_X-_Yn6IU9yx-yQDNlBenSjWhEvxp4',
    appId: '1:119820460667:android:6f9c98a326f6ca85f238de',
    messagingSenderId: '119820460667',
    projectId: 'svr-app-96763',
    databaseURL: 'https://svr-app-96763-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'svr-app-96763.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyADDLYxBmsbZ-fdwOOxxt1H8GuoUYLTd8Q',
    appId: '1:119820460667:ios:8a04dd21ef57bff5f238de',
    messagingSenderId: '119820460667',
    projectId: 'svr-app-96763',
    databaseURL: 'https://svr-app-96763-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'svr-app-96763.firebasestorage.app',
    iosBundleId: 'com.example.svrApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyADDLYxBmsbZ-fdwOOxxt1H8GuoUYLTd8Q',
    appId: '1:119820460667:ios:8a04dd21ef57bff5f238de',
    messagingSenderId: '119820460667',
    projectId: 'svr-app-96763',
    databaseURL: 'https://svr-app-96763-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'svr-app-96763.firebasestorage.app',
    iosBundleId: 'com.example.svrApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBYourApiKeyHere',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'svr-app-test',
    authDomain: 'svr-app-test.firebaseapp.com',
    storageBucket: 'svr-app-test.appspot.com',
  );
} 