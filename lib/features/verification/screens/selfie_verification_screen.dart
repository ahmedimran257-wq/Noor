// lib/features/verification/screens/selfie_verification_screen.dart
// ============================================================
// MITHAQ — Selfie Verification Screen
//
// 4-step flow:
//   Step 0: Intro — "Verify Your Profile" with trust benefits
//   Step 1: Challenge — Shows random challenge + "Open Camera" CTA
//   Step 2: Processing — ML Kit analysis with animated feedback
//   Step 3: Result — Success (teal) or Failure (coral) with actions
//
// Design: MITHAQ DNA — obsidian background, gold accents,
//         Playfair headings, Inter body, glassmorphism cards.
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/services/selfie_verification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key});

  @override
  State<SelfieVerificationScreen> createState() =>
      _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _picker = ImagePicker();
  final _service = SelfieVerificationService.instance;

  VerificationChallenge? _challenge;
  ValidationResult? _result;
  bool _isProcessing = false;
  bool _isSubmitting = false;
  Uint8List? _capturedBytes;
  int _attemptsUsed = 0;
  bool _alreadyVerified = false;
  bool _isLoadingStatus = true;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _checkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _checkStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoadingStatus = true);
    try {
      final status = await _service.getStatus();
      if (!mounted) return;
      if (status.status == 'verified') {
        setState(() => _alreadyVerified = true);
      } else {
        setState(() => _alreadyVerified = false);
      }
      setState(() => _attemptsUsed = status.attempts);
    } catch (e) {
      debugPrint('SelfieVerificationScreen: Error checking status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: AppDimensions.durationReveal,
      curve: Curves.easeOutCubic,
    );
  }

  void _startVerification() {
    _challenge = _service.generateChallenge();
    _goToStep(1);
  }

  Future<void> _captureAndValidate() async {
    if (_isProcessing) return;

    try {
      // Camera only — no gallery
      final XFile? xfile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (xfile == null || !mounted) return;

      setState(() => _isProcessing = true);
      _goToStep(2);

      // Compress to webp
      Uint8List bytes;
      final compressed = await FlutterImageCompress.compressWithFile(
        xfile.path,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
        format: CompressFormat.webp,
        keepExif: false,
      );
      bytes = compressed ?? await File(xfile.path).readAsBytes();
      _capturedBytes = bytes;

      // Run ML Kit validation
      final result = await _service.validateSelfie(bytes, _challenge!);

      if (!mounted) return;

      setState(() {
        _result = result;
        _isProcessing = false;
      });

      if (result.isValid) {
        // Success — submit to server
        setState(() => _isSubmitting = true);
        await _service.submitVerification(
          challenge: _challenge!,
          photoBytes: bytes,
        );
        if (!mounted) return;

        setState(() {
          _isSubmitting = false;
          _alreadyVerified = true;
        });
        _checkController.forward();
        _goToStep(3);
      } else {
        // Failure — record attempt
        _attemptsUsed++;
        await _service.recordFailedAttempt();
        _goToStep(3);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _result = const ValidationResult.failure(FaceValidationError.noFace);
        });
        _goToStep(3);
      }
    }
  }

  void _retryChallenge() {
    if (_attemptsUsed >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Maximum 5 attempts reached today. Please try again tomorrow.',
            style: AppTypography.body,
          ),
          backgroundColor: AppColors.softCoral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      );
      return;
    }
    _challenge = _service.generateChallenge();
    _result = null;
    _capturedBytes = null;
    _checkController.reset();
    _goToStep(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      return const Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.champagneGold,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.pearlWhite, size: 20),
        ),
        title: Text('Verify Profile',
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _IntroStep(
            onStart: _startVerification,
            isAlreadyVerified: _alreadyVerified,
          ),
          _ChallengeStep(
            challenge: _challenge,
            onCapture: _captureAndValidate,
            attemptsUsed: _attemptsUsed,
          ),
          _ProcessingStep(
            pulseAnimation: _pulseAnimation,
            isSubmitting: _isSubmitting,
          ),
          _ResultStep(
            result: _result,
            capturedBytes: _capturedBytes,
            challenge: _challenge,
            checkAnimation: _checkAnimation,
            attemptsUsed: _attemptsUsed,
            onRetry: _retryChallenge,
            onDone: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Step 0: Intro ─────────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.onStart,
    required this.isAlreadyVerified,
  });

  final VoidCallback onStart;
  final bool isAlreadyVerified;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.horizontalMargin,
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Shield icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.champagneGold.withValues(alpha: 0.2),
                  AppColors.champagneGold.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: AppColors.goldBorder,
                width: 2,
              ),
            ),
            child: Icon(
              isAlreadyVerified
                  ? Icons.verified_rounded
                  : Icons.shield_outlined,
              color: isAlreadyVerified
                  ? AppColors.verifiedTeal
                  : AppColors.champagneGold,
              size: 44,
            ),
          ),

          const SizedBox(height: AppDimensions.space32),

          // Title
          Text(
            isAlreadyVerified ? 'Already Verified' : 'Verify Your Profile',
            style: AppTypography.screenTitle,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.space12),

          // Subtitle
          Text(
            isAlreadyVerified
                ? 'Your profile has been verified with a selfie challenge. Other members can see your verified badge.'
                : 'Complete a quick selfie challenge to earn a verified badge. Verified profiles receive 3× more interest.',
            style: AppTypography.body.copyWith(
              color: AppColors.slateMist,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.space40),

          // Trust benefits
          if (!isAlreadyVerified) ...[
            const _BenefitRow(
              icon: Icons.verified_rounded,
              label: 'Verified badge on your profile',
            ),
            const SizedBox(height: AppDimensions.space12),
            const _BenefitRow(
              icon: Icons.trending_up_rounded,
              label: 'Higher ranking in search results',
            ),
            const SizedBox(height: AppDimensions.space12),
            const _BenefitRow(
              icon: Icons.favorite_outline_rounded,
              label: '3× more interest from matches',
            ),
            const SizedBox(height: AppDimensions.space12),
            const _BenefitRow(
              icon: Icons.lock_outline_rounded,
              label: 'Processed on-device — your selfie stays private',
            ),
          ],

          const Spacer(flex: 3),

          // CTA
          if (!isAlreadyVerified)
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: onStart,
                child: const Text('Start Verification',
                    style: AppTypography.button),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.verifiedTeal),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Done',
                    style: AppTypography.buttonSecondary.copyWith(
                      color: AppColors.verifiedTeal,
                    )),
              ),
            ),

          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.champagneGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Icon(icon, color: AppColors.champagneGold, size: 16),
        ),
        const SizedBox(width: AppDimensions.space12),
        Expanded(
          child: Text(label, style: AppTypography.body),
        ),
      ],
    );
  }
}

// ── Step 1: Challenge ─────────────────────────────────────────

class _ChallengeStep extends StatelessWidget {
  const _ChallengeStep({
    required this.challenge,
    required this.onCapture,
    required this.attemptsUsed,
  });

  final VerificationChallenge? challenge;
  final VoidCallback onCapture;
  final int attemptsUsed;

  IconData _challengeIcon(VerificationChallenge c) {
    switch (c) {
      case VerificationChallenge.smile:
        return Icons.sentiment_satisfied_alt_rounded;
      case VerificationChallenge.turnLeft:
        return Icons.turn_slight_left_rounded;
      case VerificationChallenge.turnRight:
        return Icons.turn_slight_right_rounded;
      case VerificationChallenge.lookUp:
        return Icons.arrow_upward_rounded;
      case VerificationChallenge.lookDown:
        return Icons.arrow_downward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (challenge == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.horizontalMargin,
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Challenge card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.space32),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.goldBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.champagneGold.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Challenge icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.champagneGold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.champagneGold.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _challengeIcon(challenge!),
                    color: AppColors.champagneGold,
                    size: 36,
                  ),
                ),

                const SizedBox(height: AppDimensions.space24),

                // "YOUR CHALLENGE" label
                Text(
                  'YOUR CHALLENGE',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.champagneGold,
                    letterSpacing: 2.0,
                  ),
                ),

                const SizedBox(height: AppDimensions.space12),

                // Challenge instruction
                Text(
                  challenge!.instruction,
                  style: AppTypography.screenTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppDimensions.space16),

                // Help text
                Text(
                  'Take a selfie while performing this action.\n'
                  'Your front camera will open automatically.',
                  style: AppTypography.caption.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Attempt counter
          if (attemptsUsed > 0)
            Text(
              '${5 - attemptsUsed} attempts remaining today',
              style: AppTypography.caption.copyWith(
                color: attemptsUsed >= 4
                    ? AppColors.softCoral
                    : AppColors.slateMist,
              ),
            ),

          const Spacer(flex: 3),

          // Tips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.space12),
            decoration: BoxDecoration(
              color: AppColors.goldGlow,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: AppColors.champagneGold, size: 18),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: Text(
                    'Good lighting and a clear background work best.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.space20),

          // Capture button
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.obsidianNight, size: 20),
              label: const Text('Open Camera', style: AppTypography.button),
              onPressed: onCapture,
            ),
          ),

          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

// ── Step 2: Processing ────────────────────────────────────────

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    required this.pulseAnimation,
    required this.isSubmitting,
  });

  final Animation<double> pulseAnimation;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing face icon
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.champagneGold.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.champagneGold.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: AppColors.champagneGold,
                    size: 44,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: AppDimensions.space32),

          // Status text
          Text(
            isSubmitting ? 'Submitting...' : 'Analysing selfie...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.champagneGold,
            ),
          ),

          const SizedBox(height: AppDimensions.space12),

          Text(
            isSubmitting
                ? 'Saving verification'
                : 'Checking face • Verifying challenge',
            style: AppTypography.caption,
          ),

          const SizedBox(height: AppDimensions.space32),

          // Progress indicator
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.surfaceGlass,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.champagneGold.withValues(alpha: 0.6),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Result ────────────────────────────────────────────

class _ResultStep extends StatelessWidget {
  const _ResultStep({
    required this.result,
    required this.capturedBytes,
    required this.challenge,
    required this.checkAnimation,
    required this.attemptsUsed,
    required this.onRetry,
    required this.onDone,
  });

  final ValidationResult? result;
  final Uint8List? capturedBytes;
  final VerificationChallenge? challenge;
  final Animation<double> checkAnimation;
  final int attemptsUsed;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final isSuccess = result?.isValid ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.horizontalMargin,
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Result icon
          if (isSuccess)
            ScaleTransition(
              scale: checkAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.verifiedTeal.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.verifiedTeal,
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.verifiedTeal,
                  size: 50,
                ),
              ),
            )
          else
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softCoral.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.softCoral,
                  width: 2.5,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.softCoral,
                size: 50,
              ),
            ),

          const SizedBox(height: AppDimensions.space32),

          // Title
          Text(
            isSuccess ? 'Verification Complete!' : 'Verification Failed',
            style: AppTypography.screenTitle.copyWith(
              color: isSuccess ? AppColors.verifiedTeal : AppColors.softCoral,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.space12),

          // Message
          Text(
            isSuccess
                ? 'Your profile now has a verified badge. Other members can trust that you are a real person.'
                : result?.errorMessage ??
                    'Verification could not be completed.',
            style: AppTypography.body.copyWith(
              color: AppColors.slateMist,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          if (!isSuccess && attemptsUsed < 5) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              '${5 - attemptsUsed} attempts remaining today',
              style: AppTypography.caption.copyWith(
                color: AppColors.slateMist,
              ),
            ),
          ],

          // Captured selfie thumbnail (success only)
          if (isSuccess && capturedBytes != null) ...[
            const SizedBox(height: AppDimensions.space24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(
                  color: AppColors.verifiedTeal.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(capturedBytes!, fit: BoxFit.cover),
            ),
          ],

          const Spacer(flex: 3),

          // Action buttons
          if (isSuccess)
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verifiedTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: onDone,
                child: Text('Continue',
                    style: AppTypography.button.copyWith(
                      color: AppColors.obsidianNight,
                    )),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: attemptsUsed >= 5 ? null : onRetry,
                child: Text(
                  attemptsUsed >= 5 ? 'Try Again Tomorrow' : 'Try Again',
                  style: AppTypography.button,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: onDone,
                child: const Text('Skip for Now',
                    style: AppTypography.buttonGhost),
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}
