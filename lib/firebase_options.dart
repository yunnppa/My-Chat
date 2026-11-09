// Firebase options for ChatApp (project: chat-app-cadc9).
// Regenerate with: dart pub global activate flutterfire_cli && flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured {
    final options = currentPlatformOrNull;
    return options != null;
  }

  static FirebaseOptions get currentPlatform {
    final options = currentPlatformOrNull;
    if (options == null) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for this platform.',
      );
    }
    return options;
  }

  static FirebaseOptions? get currentPlatformOrNull {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDVjAJ6DPLNpwsPDVyPbO83eQPc3AflT7A',
    appId: '1:650989190024:android:e2120843d56f35d0cad83d',
    messagingSenderId: '650989190024',
    projectId: 'chat-app-cadc9',
    storageBucket: 'chat-app-cadc9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCEe3z6v_RpSB_8jnYtW4lDdeEncJv3UGc',
    appId: '1:650989190024:ios:9ef2781d35b7f686cad83d',
    messagingSenderId: '650989190024',
    projectId: 'chat-app-cadc9',
    storageBucket: 'chat-app-cadc9.firebasestorage.app',
    iosBundleId: 'com.chatapp.chatApp',
  );
}
