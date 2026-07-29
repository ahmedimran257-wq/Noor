import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration is supplied by the same reviewed release-config file
/// as the rest of the production services. Native files and Dart options are
/// checked for equality by tool/verify_firebase_config.py before a release.
class DefaultFirebaseOptions {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.silarah.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web config is not enabled.');
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'Firebase is configured only for Android and iOS builds.',
        ),
    };
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _required('FIREBASE_ANDROID_API_KEY', _androidApiKey),
        appId: _required('FIREBASE_ANDROID_APP_ID', _androidAppId),
        messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID', _senderId),
        projectId: _required('FIREBASE_PROJECT_ID', _projectId),
        storageBucket: _required('FIREBASE_STORAGE_BUCKET', _storageBucket),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _required('FIREBASE_IOS_API_KEY', _iosApiKey),
        appId: _required('FIREBASE_IOS_APP_ID', _iosAppId),
        messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID', _senderId),
        projectId: _required('FIREBASE_PROJECT_ID', _projectId),
        storageBucket: _required('FIREBASE_STORAGE_BUCKET', _storageBucket),
        iosBundleId: _required('FIREBASE_IOS_BUNDLE_ID', _iosBundleId),
      );

  static String _required(String name, String value) {
    if (value.trim().isEmpty ||
        value.contains('YOUR_') ||
        value.contains('PLACEHOLDER')) {
      throw StateError('$name is required for this Firebase build.');
    }
    return value;
  }
}
