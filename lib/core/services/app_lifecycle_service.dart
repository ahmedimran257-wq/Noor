import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Narrow bridge for lifecycle operations that Flutter cannot perform alone.
abstract final class AppLifecycleService {
  static const MethodChannel _channel = MethodChannel(
    'com.silarah.app/app_lifecycle',
  );

  static bool get supportsInPlaceRestart =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Recreates the Android application task and Flutter engine.
  ///
  /// Returns only when the platform could not accept the restart request. A
  /// successful request destroys this Flutter surface as the replacement task
  /// starts, while authentication and preferences remain persisted normally.
  static Future<bool> restartNow() async {
    if (!supportsInPlaceRestart) return false;
    try {
      return await _channel.invokeMethod<bool>('restartApp') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
