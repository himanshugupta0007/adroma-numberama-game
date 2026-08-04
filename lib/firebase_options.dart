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
    apiKey: 'AIzaSyB3aGa5EE5kRcirkhIzKYZ4NBhi1zd__Eo',
    appId: '1:933332666357:android:9ecff65a8a930cd619c2bc',
    messagingSenderId: '933332666357',
    projectId: 'adroma-numberama',
    storageBucket: 'adroma-numberama.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCRPNlnFdRhpQdy8zvV8M5eCQglzCcvixo',
    appId: '1:933332666357:ios:96576389a9cecf3119c2bc',
    messagingSenderId: '933332666357',
    projectId: 'adroma-numberama',
    storageBucket: 'adroma-numberama.firebasestorage.app',
    iosBundleId: 'com.adroma.numberama',
  );
}
