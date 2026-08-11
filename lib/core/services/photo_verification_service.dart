import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum PhotoVerificationState {
  notStarted,
  uploading,
  pending,
  approved,
  resubmit,
  rejected,
  expired,
  revoked,
}

class PhotoVerificationStatus {
  const PhotoVerificationStatus({
    required this.state,
    required this.canSubmit,
    this.submittedAt,
    this.reviewDeadline,
    this.reviewedAt,
    this.reason,
    this.capturesPurgedAt,
    this.photoVerifiedAt,
    this.pausedAt,
    this.pauseReason,
  });

  const PhotoVerificationStatus.notStarted()
      : state = PhotoVerificationState.notStarted,
        canSubmit = true,
        submittedAt = null,
        reviewDeadline = null,
        reviewedAt = null,
        reason = null,
        capturesPurgedAt = null,
        photoVerifiedAt = null,
        pausedAt = null,
        pauseReason = null;

  final PhotoVerificationState state;
  final bool canSubmit;
  final DateTime? submittedAt;
  final DateTime? reviewDeadline;
  final DateTime? reviewedAt;
  final String? reason;
  final DateTime? capturesPurgedAt;
  final DateTime? photoVerifiedAt;
  final DateTime? pausedAt;
  final String? pauseReason;

  bool get isApproved =>
      state == PhotoVerificationState.approved && pausedAt == null;
  bool get isPending => state == PhotoVerificationState.pending;
}

class PhotoVerificationUpload {
  const PhotoVerificationUpload({
    required this.submissionId,
    required this.reviewDeadline,
    required this.uploads,
  });

  final String submissionId;
  final DateTime reviewDeadline;
  final Map<String, ({String path, String token})> uploads;
}

class PhotoVerificationService {
  PhotoVerificationService._();

  static final instance = PhotoVerificationService._();
  static const _bucket = 'photo-verification-captures';

  Future<PhotoVerificationStatus> fetchStatus() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return const PhotoVerificationStatus.notStarted();
    }
    final response =
        await SupabaseService.client.rpc('get_my_photo_verification_status');
    final row = switch (response) {
      final List value when value.isNotEmpty && value.first is Map =>
        Map<String, dynamic>.from(value.first as Map),
      final Map value => Map<String, dynamic>.from(value),
      _ => null,
    };
    if (row == null) return const PhotoVerificationStatus.notStarted();
    return PhotoVerificationStatus(
      state: _parseState(row['status']?.toString()),
      canSubmit: row['can_submit'] as bool? ?? true,
      submittedAt: _date(row['submitted_at']),
      reviewDeadline: _date(row['review_deadline']),
      reviewedAt: _date(row['reviewed_at']),
      reason: _text(row['reason']),
      capturesPurgedAt: _date(row['captures_purged_at']),
      photoVerifiedAt: _date(row['photo_verified_at']),
      pausedAt: _date(row['paused_at']),
      pauseReason: _text(row['pause_reason']),
    );
  }

  Future<PhotoVerificationUpload> start({
    bool accessibilityFallback = false,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'photo-verification',
      body: {
        'action': 'start',
        'guidance_mode': accessibilityFallback
            ? 'manual_accessibility_v1'
            : 'smile_blink_v1',
      },
    );
    final payload = _payload(response, 'Unable to start photo verification.');
    final submissionId = _text(payload['submission_id']);
    final deadline = _date(payload['review_deadline']);
    final rawUploads = payload['uploads'];
    if (submissionId == null || deadline == null || rawUploads is! Map) {
      throw StateError('The secure verification response was incomplete.');
    }
    final uploads = <String, ({String path, String token})>{};
    for (final kind in const ['neutral', 'smile', 'blink']) {
      final raw = rawUploads[kind];
      if (raw is! Map) {
        throw StateError('The secure verification response was incomplete.');
      }
      final path = _text(raw['path']);
      final token = _text(raw['token']);
      if (path == null || token == null) {
        throw StateError('The secure verification response was incomplete.');
      }
      uploads[kind] = (path: path, token: token);
    }
    return PhotoVerificationUpload(
      submissionId: submissionId,
      reviewDeadline: deadline,
      uploads: uploads,
    );
  }

  Future<DateTime> uploadAndSubmit({
    required Map<String, File> captures,
    required bool accessibilityFallback,
  }) async {
    final session = await start(
      accessibilityFallback: accessibilityFallback,
    );
    for (final kind in const ['neutral', 'smile', 'blink']) {
      final source = captures[kind];
      final target = session.uploads[kind];
      if (source == null || target == null) {
        throw StateError('All three guided captures are required.');
      }
      final bytes = await FlutterImageCompress.compressWithFile(
        source.path,
        minWidth: 900,
        minHeight: 900,
        quality: 78,
        format: CompressFormat.jpeg,
      );
      if (bytes == null ||
          bytes.length < 10000 ||
          bytes.length > 2 * 1024 * 1024) {
        throw StateError('A clear verification photo could not be prepared.');
      }
      await SupabaseService.client.storage
          .from(_bucket)
          .uploadBinaryToSignedUrl(
            target.path,
            target.token,
            bytes,
            const FileOptions(contentType: 'image/jpeg', upsert: false),
          );
    }
    final submitted = await SupabaseService.client.functions.invoke(
      'photo-verification',
      body: {'action': 'submit', 'submission_id': session.submissionId},
    );
    final payload = _payload(
      submitted,
      'Unable to submit photo verification for review.',
    );
    return _date(payload['review_deadline']) ?? session.reviewDeadline;
  }

  Map<String, dynamic> _payload(
    FunctionResponse response,
    String fallback,
  ) {
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map) {
      if (data is Map) {
        final message = _text(data['error']);
        if (message != null) throw StateError(message);
      }
      throw StateError(fallback);
    }
    return Map<String, dynamic>.from(data);
  }

  static PhotoVerificationState _parseState(String? value) => switch (value) {
        'uploading' => PhotoVerificationState.uploading,
        'pending' => PhotoVerificationState.pending,
        'approved' => PhotoVerificationState.approved,
        'resubmit' => PhotoVerificationState.resubmit,
        'rejected' => PhotoVerificationState.rejected,
        'expired' => PhotoVerificationState.expired,
        'revoked' => PhotoVerificationState.revoked,
        _ => PhotoVerificationState.notStarted,
      };

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  static String? _text(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
