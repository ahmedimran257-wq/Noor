import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/services/kyc_verification_service.dart';
import '../../../core/services/media_permission_error.dart';
import '../../../core/services/platform_action_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  final _picker = ImagePicker();
  final _service = KycVerificationService.instance;
  File? _selfie;
  File? _idPhoto;
  String _idType = 'government_id';
  String _countryCodeValue = '';
  bool _submitting = false;
  bool _statusLoading = true;
  KycStatusSnapshot _status = const KycStatusSnapshot.notStarted();
  KycVerificationResult? _result;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    _countryCodeValue =
        auth is AuthAuthenticated ? auth.countryCode?.toUpperCase() ?? '' : '';
    if (_countryCodeValue.isEmpty) _loadProfileCountry();
    unawaited(_loadStatus());
  }

  String get _countryCode => _countryCodeValue;

  Future<void> _loadStatus() async {
    try {
      final status = await _service.fetchStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _statusLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _loadProfileCountry() async {
    final userId = SupabaseService.currentUserId;
    if (!SupabaseService.isInitialized || userId == null) return;
    try {
      final profile = await SupabaseService.client
          .from('my_profile_private')
          .select('country_code')
          .eq('user_id', userId)
          .maybeSingle();
      final countryCode = profile?['country_code'] as String?;
      if (mounted && countryCode != null && countryCode.isNotEmpty) {
        setState(() => _countryCodeValue = countryCode.toUpperCase());
      }
    } catch (_) {
      // The standard flow remains available as soon as profile country loads.
    }
  }

  Future<void> _pickSelfie() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 92,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (image != null && mounted) setState(() => _selfie = File(image.path));
    } catch (error) {
      if (mounted) await _showCaptureError(error);
    }
  }

  Future<void> _pickId() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (image != null && mounted) setState(() => _idPhoto = File(image.path));
    } catch (error) {
      if (mounted) await _showCaptureError(error);
    }
  }

  Future<void> _showCaptureError(Object error) async {
    final denied = MediaPermissionError.isPermissionDenied(error);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            denied ? l10n.media_cameraAccessOff : l10n.media_cameraUnavailable),
        content: Text(
          denied
              ? l10n.media_cameraAccessBody
              : l10n.media_cameraUnavailableBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.common_button_cancel),
          ),
          if (denied)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await PlatformActionService.instance.openAppSettings();
              },
              child: Text(l10n.common_openSettings),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final selfie = _selfie;
    final idPhoto = _idPhoto;
    if (selfie == null || idPhoto == null || _countryCode.isEmpty) return;
    setState(() {
      _submitting = true;
      _result = null;
    });
    try {
      final result = await _service.verify(
        selfie: selfie,
        idPhoto: idPhoto,
        idType: _idType,
        countryCode: _countryCode,
      );
      final status = await _service.fetchStatus();
      if (mounted) {
        setState(() {
          _result = result;
          _status = status;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = const KycVerificationResult(
            status: KycVerificationStatus.notStarted,
            message:
                'Your submission was not completed. Check your connection and try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready =
        _selfie != null && _idPhoto != null && _countryCode.isNotEmpty;
    final submissionLocked = _status.isApproved || _status.isPending;
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        foregroundColor: AppColors.pearlWhite,
        title: Text(l10n.kyc_title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.space24),
          children: [
            Text(l10n.kyc_heading, style: AppTypography.screenTitle),
            const SizedBox(height: AppDimensions.space8),
            Text(
              l10n.kyc_intro,
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppDimensions.space20),
            _KycStatusPanel(
              loading: _statusLoading,
              snapshot: _status,
            ),
            if (!submissionLocked) ...[
              const SizedBox(height: AppDimensions.space28),
              _CaptureTile(
                title: l10n.kyc_selfieTitle,
                subtitle: _selfie == null
                    ? l10n.kyc_selfieHint
                    : l10n.kyc_selfieCaptured,
                icon: Icons.face_retouching_natural_outlined,
                complete: _selfie != null,
                onTap: _pickSelfie,
              ),
              const SizedBox(height: AppDimensions.space12),
              _CaptureTile(
                title: l10n.kyc_idTitle,
                subtitle:
                    _idPhoto == null ? l10n.kyc_idHint : l10n.kyc_idCaptured,
                icon: Icons.badge_outlined,
                complete: _idPhoto != null,
                onTap: _pickId,
              ),
              const SizedBox(height: AppDimensions.space20),
              DropdownButtonFormField<String>(
                initialValue: _idType,
                dropdownColor: AppColors.surfaceMid,
                style: AppTypography.body,
                decoration: InputDecoration(labelText: l10n.kyc_documentType),
                items: [
                  DropdownMenuItem(
                      value: 'government_id',
                      child: Text(l10n.kyc_governmentId)),
                  DropdownMenuItem(
                      value: 'passport', child: Text(l10n.kyc_passport)),
                  DropdownMenuItem(
                      value: 'driving_license',
                      child: Text(l10n.kyc_drivingLicence)),
                ],
                onChanged: (value) =>
                    setState(() => _idType = value ?? _idType),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: AppDimensions.space20),
              _ResultPanel(result: _result!),
            ],
            if (!submissionLocked) ...[
              const SizedBox(height: AppDimensions.space28),
              SizedBox(
                height: AppDimensions.buttonHeight,
                child: ElevatedButton(
                  onPressed: ready && !_submitting ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          _status.status == KycVerificationStatus.notStarted
                              ? l10n.kyc_submitReview
                              : l10n.kyc_submitNewEvidence,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KycStatusPanel extends StatelessWidget {
  const _KycStatusPanel({
    required this.loading,
    required this.snapshot,
  });

  final bool loading;
  final KycStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final presentation = _statusPresentation(l10n, snapshot.status);
    final detail = snapshot.reason ?? presentation.message;
    return Semantics(
      container: true,
      label: 'Identity verification status: ${presentation.label}',
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: presentation.color.withValues(alpha: 0.42)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: presentation.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                presentation.icon,
                color: presentation.color,
                size: 21,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: presentation.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: AppTypography.caption),
                  if (snapshot.submittedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.kyc_submitted(
                        MaterialLocalizations.of(context)
                            .formatShortDate(snapshot.submittedAt!.toLocal()),
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.complete,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(
              color: complete ? AppColors.verifiedTeal : AppColors.cardBorder),
        ),
        leading: Icon(icon,
            color: complete ? AppColors.verifiedTeal : AppColors.champagneGold),
        title: Text(title, style: AppTypography.bodyMedium),
        subtitle: Text(subtitle, style: AppTypography.caption),
        trailing: Icon(
            complete ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
            color: complete ? AppColors.verifiedTeal : AppColors.slateMist),
      );
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});
  final KycVerificationResult result;

  @override
  Widget build(BuildContext context) {
    final presentation =
        _statusPresentation(AppLocalizations.of(context), result.status);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: presentation.color.withValues(alpha: 0.5)),
      ),
      child: Text(result.message,
          style: AppTypography.body.copyWith(color: presentation.color)),
    );
  }
}

({String label, String message, Color color, IconData icon})
    _statusPresentation(
  AppLocalizations l10n,
  KycVerificationStatus status,
) =>
        switch (status) {
          KycVerificationStatus.approved => (
              label: l10n.kyc_statusApproved,
              message: l10n.kyc_statusApprovedBody,
              color: AppColors.verifiedTeal,
              icon: Icons.verified_user_outlined,
            ),
          KycVerificationStatus.pendingReview => (
              label: l10n.kyc_statusPending,
              message: l10n.kyc_statusPendingBody,
              color: AppColors.champagneGold,
              icon: Icons.hourglass_top_rounded,
            ),
          KycVerificationStatus.rejected => (
              label: l10n.kyc_statusRejected,
              message: l10n.kyc_statusRejectedBody,
              color: AppColors.softCoral,
              icon: Icons.gpp_bad_outlined,
            ),
          KycVerificationStatus.resubmitRequired => (
              label: l10n.kyc_statusResubmit,
              message: l10n.kyc_statusResubmitBody,
              color: AppColors.softCoral,
              icon: Icons.refresh_rounded,
            ),
          KycVerificationStatus.expired => (
              label: l10n.kyc_statusExpired,
              message: l10n.kyc_statusExpiredBody,
              color: AppColors.champagneGold,
              icon: Icons.event_busy_outlined,
            ),
          KycVerificationStatus.notStarted => (
              label: l10n.kyc_statusNotStarted,
              message: l10n.kyc_statusNotStartedBody,
              color: AppColors.slateMist,
              icon: Icons.shield_outlined,
            ),
        };
