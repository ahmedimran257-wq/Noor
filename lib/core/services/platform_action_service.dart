import 'package:flutter/services.dart';

/// Small native platform actions kept behind one testable boundary.
class PlatformActionService {
  PlatformActionService._();

  static final instance = PlatformActionService._();
  static const _channel = MethodChannel('com.silarah.app/platform_actions');

  Future<void> openAppSettings() async {
    await _channel.invokeMethod<void>('openAppSettings');
  }

  Future<void> shareText({required String text, String? subject}) async {
    await _channel.invokeMethod<void>('shareText', {
      'text': text,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
    });
  }
}
