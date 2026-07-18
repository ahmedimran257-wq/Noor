import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/photo_moderation_service.dart';

void main() {
  test('bundled moderation model matches its production integrity contract',
      () async {
    final model = File(PhotoModerationService.modelAssetPath);
    expect(await model.exists(), isTrue);
    final bytes = await model.readAsBytes();
    expect(bytes.length, PhotoModerationService.modelBytes);
    expect(
      sha256.convert(bytes).toString(),
      PhotoModerationService.modelSha256,
    );
    expect(PhotoModerationService.modelSource, 'bhky/opennsfw2');
  });

  test('obsolete oversized Falconsai model is not shipped', () async {
    expect(await File('assets/models/falconsai_nsfw.tflite').exists(), isFalse);
    final pubspec = await File('pubspec.yaml').readAsString();
    expect(pubspec, isNot(contains('falconsai_nsfw.tflite')));
    expect(pubspec, contains('opennsfw2_float16.tflite'));
  });
}
