import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android release signing integrity', () {
    late String gradle;
    late String workflow;

    setUpAll(() {
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
      workflow = File('.github/workflows/ci.yml').readAsStringSync();
    });

    test('production builds use a dedicated external signing identity', () {
      expect(gradle, contains('create("release")'));
      expect(gradle, contains('SILARAH_SIGNING_PROPERTIES'));
      expect(
        gradle,
        contains('.silarah/release-signing/key.properties'),
      );
      expect(
        gradle,
        contains('signingConfig = signingConfigs.getByName("release")'),
      );
      expect(
        gradle,
        isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
      );
    });

    test('every release artifact is guarded against debug signing', () {
      expect(gradle, contains('tasks.register("verifyReleaseSigning")'));
      expect(gradle, contains('releaseStore == debugStore'));
      expect(gradle, contains('dependsOn("verifyReleaseSigning")'));
    });

    test('CI exercises the guarded AAB path with a disposable identity', () {
      expect(workflow, contains('Create CI-only Android signing identity'));
      expect(workflow, contains('./gradlew verifyReleaseSigning'));
      expect(workflow, contains('flutter build appbundle --release'));
    });

    test('signing secrets and keystores stay outside source control', () {
      final androidIgnore = File('android/.gitignore').readAsStringSync();
      expect(androidIgnore, contains('key.properties'));
      expect(androidIgnore, contains('**/*.keystore'));
      expect(androidIgnore, contains('**/*.jks'));
      expect(File('android/key.properties').existsSync(), isFalse);
    });
  });
}
