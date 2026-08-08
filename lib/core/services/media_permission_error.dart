import 'package:flutter/services.dart';

abstract final class MediaPermissionError {
  static bool isPermissionDenied(Object error) {
    if (error is! PlatformException) return false;
    final code = error.code.toLowerCase();
    return code.contains('access_denied') ||
        code.contains('permission_denied') ||
        code.contains('camera_access') ||
        code.contains('photo_access');
  }
}
