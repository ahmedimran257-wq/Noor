import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'profile_photo_service.dart';
import 'supabase_service.dart';

class PersonalDataExportResult {
  const PersonalDataExportResult({
    required this.filePath,
    required this.photoCount,
    required this.shareStatus,
  });

  final String filePath;
  final int photoCount;
  final ShareResultStatus shareStatus;

  bool get wasDismissed => shareStatus == ShareResultStatus.dismissed;
}

/// Builds a private, machine-readable archive and opens the platform save/share
/// sheet. The backend is authoritative for the data boundary; the client only
/// adds the member's currently accessible profile-photo files to the archive.
class PersonalDataExportService {
  PersonalDataExportService._();

  static final instance = PersonalDataExportService._();

  static const _maxPhotoBytes = 15 * 1024 * 1024;

  Future<PersonalDataExportResult> createAndShare({
    Rect? sharePositionOrigin,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Could not connect to Silarah. Please try again.');
    }
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) {
      throw StateError('Please sign in again to download your data.');
    }
    final package = await PackageInfo.fromPlatform();
    final response = await SupabaseService.client.rpc(
      'download_my_data',
      params: {'p_client_version': '${package.version}+${package.buildNumber}'},
    );
    if (response is! Map) {
      throw StateError('Your data export could not be prepared. Try again.');
    }

    final export = Map<String, dynamic>.from(response);
    final archive = Archive();
    archive.addFile(ArchiveFile.string(
      'silarah-data.json',
      const JsonEncoder.withIndent('  ').convert(export),
    ));

    var photoCount = 0;
    final photoFailures = <String>[];
    final client = http.Client();
    try {
      final photoSlots = await ProfilePhotoService.instance.getMyPhotoSlots();
      for (final entry in photoSlots.entries) {
        try {
          final photo = await client
              .get(Uri.parse(entry.value))
              .timeout(const Duration(seconds: 20));
          if (photo.statusCode != 200 ||
              photo.bodyBytes.isEmpty ||
              photo.bodyBytes.length > _maxPhotoBytes) {
            photoFailures
                .add('Photo slot ${entry.key + 1} could not be added.');
            continue;
          }
          final extension = _extensionFor(photo.headers['content-type']);
          archive.addFile(ArchiveFile.bytes(
            'profile-photos/photo-${entry.key + 1}.$extension',
            photo.bodyBytes,
          ));
          photoCount += 1;
        } catch (_) {
          photoFailures.add('Photo slot ${entry.key + 1} could not be added.');
        }
      }
    } finally {
      client.close();
    }

    archive.addFile(ArchiveFile.string(
      'README.txt',
      _readme(photoCount: photoCount, photoFailures: photoFailures),
    ));

    final zipBytes = ZipEncoder().encode(archive);
    final tempDirectory = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}silarah-data-export-$stamp.zip',
    );
    await file.writeAsBytes(zipBytes, flush: true);

    try {
      return await _shareArchive(
        file,
        photoCount: photoCount,
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      // Share targets receive a content-URI copy. The clear-text local ZIP is
      // not a cache and must not survive after the platform sheet returns.
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<PersonalDataExportResult> _shareArchive(
    File file, {
    required int photoCount,
    Rect? sharePositionOrigin,
  }) async {
    final fileName = file.uri.pathSegments.last;
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/zip')],
      fileNameOverrides: [fileName],
      subject: 'My Silarah data export',
      text:
          'Private account archive. Store it securely and share it only with people you trust.',
      sharePositionOrigin: sharePositionOrigin,
    ));
    return PersonalDataExportResult(
      filePath: file.path,
      photoCount: photoCount,
      shareStatus: result.status,
    );
  }

  String _extensionFor(String? contentType) {
    final normalized = contentType?.toLowerCase() ?? '';
    if (normalized.contains('png')) return 'png';
    if (normalized.contains('webp')) return 'webp';
    if (normalized.contains('heic')) return 'heic';
    return 'jpg';
  }

  String _readme({
    required int photoCount,
    required List<String> photoFailures,
  }) {
    final failed = photoFailures.isEmpty
        ? 'All currently accessible profile photos were included.'
        : photoFailures.join('\n');
    return '''Silarah personal data export

This archive is private. It may contain contact details, profile information,
messages, matches, reports you submitted, consent records and subscription
history. Store it securely and do not upload it to a public service.

silarah-data.json is the machine-readable account archive.
profile-photos/ contains $photoCount currently accessible profile photo(s).
$failed

Passwords, one-time codes, raw push credentials, other members' confidential
reports, staff identities, privileged material and internal anti-abuse methods
are not included. Temporary verification captures are deleted on their stated
retention schedule and are not exported. For a verified request concerning an
omitted data category, contact privacy@silarah.com.
''';
  }
}
