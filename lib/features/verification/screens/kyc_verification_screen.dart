import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/services/kyc_verification_service.dart';
import '../../../core/services/digilocker_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

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
  KycVerificationResult? _result;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthCubit>().state;
    _countryCodeValue =
        auth is AuthAuthenticated ? auth.countryCode?.toUpperCase() ?? '' : '';
    if (_countryCodeValue.isEmpty) _loadProfileCountry();
  }

  String get _countryCode => _countryCodeValue;

  Future<void> _loadProfileCountry() async {
    final userId = SupabaseService.currentUserId;
    if (!SupabaseService.isInitialized || userId == null) return;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
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
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 92,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (image != null && mounted) setState(() => _selfie = File(image.path));
  }

  Future<void> _pickId() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
      maxWidth: 2200,
      maxHeight: 2200,
    );
    if (image != null && mounted) setState(() => _idPhoto = File(image.path));
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
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = const KycVerificationResult(
            status: KycVerificationStatus.rejected,
            message: 'We could not complete verification. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyWithDigiLocker() async {
    final service = DigiLockerService.instance;
    if (!service.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'DigiLocker verification is not configured on this build. Standard verification remains available.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final digilockerResult = await service.verifyIdentity();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = KycVerificationResult(
        status: switch (digilockerResult.status) {
          DigiLockerVerificationStatus.verified =>
            KycVerificationStatus.verified,
          DigiLockerVerificationStatus.insufficientEvidence =>
            KycVerificationStatus.pendingReview,
          _ => KycVerificationStatus.rejected,
        },
        message: digilockerResult.message,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _selfie != null && _idPhoto != null && _countryCode.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        foregroundColor: AppColors.pearlWhite,
        title: const Text('Verify your identity'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.space24),
          children: [
            const Text('Verify your profile', style: AppTypography.screenTitle),
            const SizedBox(height: AppDimensions.space8),
            const Text(
              'Capture-quality checks run on this device. Your private document and selfie are then reviewed by Silarah. Device scores never approve your identity.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppDimensions.space28),
            _CaptureTile(
              title: '1. Take a clear selfie',
              subtitle: _selfie == null
                  ? 'One face, good lighting'
                  : 'Selfie captured',
              icon: Icons.face_retouching_natural_outlined,
              complete: _selfie != null,
              onTap: _pickSelfie,
            ),
            const SizedBox(height: AppDimensions.space12),
            _CaptureTile(
              title: '2. Photograph your ID',
              subtitle: _idPhoto == null
                  ? 'Your name, photo and date of birth must be visible'
                  : 'ID captured',
              icon: Icons.badge_outlined,
              complete: _idPhoto != null,
              onTap: _pickId,
            ),
            const SizedBox(height: AppDimensions.space20),
            DropdownButtonFormField<String>(
              initialValue: _idType,
              dropdownColor: AppColors.surfaceMid,
              style: AppTypography.body,
              decoration: const InputDecoration(labelText: 'Document type'),
              items: const [
                DropdownMenuItem(
                    value: 'government_id', child: Text('Government ID')),
                DropdownMenuItem(value: 'passport', child: Text('Passport')),
                DropdownMenuItem(
                    value: 'driving_license', child: Text('Driving licence')),
              ],
              onChanged: (value) => setState(() => _idType = value ?? _idType),
            ),
            if (_countryCode == 'IN') ...[
              const SizedBox(height: AppDimensions.space16),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _verifyWithDigiLocker,
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Verify with DigiLocker'),
              ),
              const SizedBox(height: AppDimensions.space8),
              const Text(
                'A badge is granted only when your DigiLocker account and an authenticated issued identity document match your profile name and date of birth. Authorization alone is not verification.',
                style: AppTypography.caption,
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: AppDimensions.space20),
              _ResultPanel(result: _result!),
            ],
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
                    : const Text('Submit for private review'),
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
    final pending = result.status == KycVerificationStatus.pendingReview;
    final verified = result.status == KycVerificationStatus.verified;
    final color = verified
        ? AppColors.verifiedTeal
        : pending
            ? AppColors.champagneGold
            : AppColors.softCoral;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(result.message,
          style: AppTypography.body.copyWith(color: color)),
    );
  }
}
