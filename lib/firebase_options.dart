// File generated manually from the Android/iOS config files downloaded in
// the Firebase console (google-services.json / GoogleService-Info.plist) -
// see doc/firebase-setup.md. Matches the shape the `flutterfire configure`
// CLI would produce, so running that CLI later (once web/macos/etc. are
// registered too) is safe to just overwrite this file with.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'no web app has been registered in the Firebase console yet.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'no macOS app has been registered in the Firebase console yet.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'no Windows app has been registered in the Firebase console yet.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'no Linux app has been registered in the Firebase console yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2RA9s2-i42oA0FqvGaNfSbue5aQweY34',
    appId: '1:389425061595:android:f7556a7a9608d5d3ddb6fe',
    messagingSenderId: '389425061595',
    projectId: 'adroma-numberama-1',
    storageBucket: 'adroma-numberama-1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBylXLDZgcO_l2Pk_LsVqV0nIequUuII1E',
    appId: '1:389425061595:ios:28e0adc6de00592cddb6fe',
    messagingSenderId: '389425061595',
    projectId: 'adroma-numberama-1',
    storageBucket: 'adroma-numberama-1.firebasestorage.app',
    iosBundleId: 'com.adroma.numberama',
  );
}
