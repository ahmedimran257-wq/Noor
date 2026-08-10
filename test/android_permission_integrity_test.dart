import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release manifest removes unused sensitive transitive permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
    for (final permission in <String>[
      'android.permission.RECORD_AUDIO',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_PHONE_STATE',
    ]) {
      final declaration = RegExp(
        '<uses-permission\\s+'
        'android:name="$permission"\\s+'
        'tools:node="remove"\\s*/>',
        multiLine: true,
      );
      expect(
        manifest,
        matches(declaration),
        reason: '$permission must stay out of the merged release manifest.',
      );
    }
  });
}
