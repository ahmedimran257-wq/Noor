import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers an entry-point-safe native Firebase background handler', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains("@pragma('vm:entry-point')"),
    );
    expect(
      source,
      contains('Future<void> silarahFirebaseMessagingBackgroundHandler('),
    );
    expect(
      source,
      contains('FirebaseMessaging.onBackgroundMessage('),
    );
    expect(
      source,
      contains('await Firebase.initializeApp();'),
    );
    expect(source, isNot(contains('DefaultFirebaseOptions.currentPlatform')));
  });
}
