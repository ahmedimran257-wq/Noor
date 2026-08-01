import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/167_repair_secure_photo_upload_reservations.sql',
  ).readAsStringSync();
  final jpegMigration = File(
    'supabase/migrations/168_align_profile_photo_transport_with_server_decoder.sql',
  ).readAsStringSync();
  final bucketMigration = File(
    'supabase/migrations/169_align_profile_photo_bucket_mime.sql',
  ).readAsStringSync();
  final service = File(
    'lib/core/services/profile_photo_service.dart',
  ).readAsStringSync();

  test('secure upload reservations accept canonical photo object paths', () {
    expect(
      migration,
      contains("/[A-Za-z0-9_-]+[.](webp|jpg)\$"),
      reason: 'The path check must use an escape-independent literal dot.',
    );
    expect(
      migration,
      isNot(contains(r"/[A-Za-z0-9_-]+\\.(webp|jpg)$")),
      reason: 'The broken double-backslash PostgreSQL regex must not return.',
    );
    expect(migration, contains("auth.role() <> 'service_role'"));
    expect(migration, contains('TO service_role'));
  });

  test('client upload uses one server-decodable JPEG contract', () {
    expect(service, contains("'get-signed-url'"));
    expect(service, contains("'file_extension': 'jpg'"));
    expect(service, contains("contentType: 'image/jpeg'"));
    expect(service, contains("payload['storage_path']"));
    expect(service, contains("payload['token']"));
    expect(service, contains('uploadBinaryToSignedUrl('));
    expect(service, contains("'validate-photo-upload'"));

    final screen = File(
      'lib/features/onboarding/screens/photo_upload_screen.dart',
    ).readAsStringSync();
    final validator = File(
      'supabase/functions/validate-photo-upload/index.ts',
    ).readAsStringSync();
    final signer = File(
      'supabase/functions/get-signed-url/index.ts',
    ).readAsStringSync();
    expect(screen, contains('format: CompressFormat.jpeg'));
    expect(screen, contains("}.jpg'"));
    expect(validator, contains('function isJpeg('));
    expect(validator, contains('p_observed_mime: "image/jpeg"'));
    expect(validator, isNot(contains('function isWebp(')));
    expect(
      jpegMigration,
      contains("p_expected_mime <> 'image/jpeg'"),
    );
    expect(
      bucketMigration,
      contains("allowed_mime_types = ARRAY['image/jpeg']"),
    );
    expect(signer, contains('"already_pending"'));
    expect(service, contains("payload['action'] == 'already_pending'"));
  });
}
