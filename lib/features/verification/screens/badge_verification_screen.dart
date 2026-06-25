// lib/features/verification/screens/badge_verification_screen.dart
// ============================================================
// MITHAQ — Badge Verification Screen (Phase 2.5)
//
// 3-pose sequential liveness check for the Verification Badge.
// Each pose must be completed within a time limit.
// All 3 must pass to earn the badge.
//
// Design: MITHAQ DNA — obsidian background, gold accents,
//         glassmorphism, animated progress.
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/selfie_verification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class BadgeVerificationScreen extends StatefulWidget {
  const BadgeVerificationScreen({super.key});

  @override
  State<BadgeVerificationScreen> createState() =>
      _BadgeVerificationScreenState();
}

class _BadgeVerificationScreenState extends State<BadgeVerificationScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _service = SelfieVerificationService.instance;

  List<VerificationChallenge> _sequence = [];
  int _currentStep = 0;
  bool _isProcessing = false;
  bool _isSubmitting = false;
  bool _hasBadge = false;
  bool _isLoading = true;
  final List<bool> _stepResults = [];
  String? _errorMessage;
  int _attemptsToday = 0;

  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;

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
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkExistingBadge();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingBadge() async {
    final hasBadge = await _service.hasBadge();
    // Check daily attempt count
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('badge_attempt_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (savedDate == today) {
      _attemptsToday = prefs.getInt('badge_attempts_today') ?? 0;
    } else {
      await prefs.setString('badge_attempt_date', today);
      await prefs.setInt('badge_attempts_today', 0);
    }
    if (mounted) {
      setState(() {
        _hasBadge = hasBadge;
        _isLoading = false;
      });
    }
  }

  void _startVerification() {
    if (_attemptsToday >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Maximum 3 attempts per day. Please try again tomorrow.',
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
    setState(() {
      _sequence = _service.generateBadgeSequence();
      _currentStep = 0;
      _stepResults.clear();
      _errorMessage = null;
    });
  }

  Future<void> _captureForStep() async {
    if (_isProcessing || _currentStep >= _sequence.length) return;

    try {
      final XFile? xfile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (xfile == null || !mounted) return;

      setState(() => _isProcessing = true);

      // Compress to webp with EXIF stripped
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

      // Validate against current challenge
      final result =
          await _service.validateSelfie(bytes, _sequence[_currentStep]);

      if (!mounted) return;

      if (result.isValid) {
        _stepResults.add(true);
        if (_currentStep == 2) {
          // All 3 passed! Submit badge
          setState(() {
            _isProcessing = false;
            _isSubmitting = true;
          });

          final poseNames = _sequence.map((c) => c.dbValue).toList();
          final submitted = await _service.submitBadgeVerification(
            poseSequence: poseNames,
          );
          if (!submitted) {
            if (mounted) {
              setState(() {
                _isSubmitting = false;
                _stepResults[_stepResults.length - 1] = false;
                _errorMessage =
                    'Could not save your verification. Please try again.';
              });
            }
            return;
          }

          // Save locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_verification_badge', true);

          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _hasBadge = true;
            });
            _successController.forward();
          }
        } else {
          // Advance to next pose
          setState(() {
            _isProcessing = false;
            _currentStep++;
          });
        }
      } else {
        // Step failed — badge attempt failed
        _stepResults.add(false);
        _attemptsToday++;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('badge_attempts_today', _attemptsToday);

        setState(() {
          _isProcessing = false;
          _errorMessage = result.errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Camera error. Please try again.';
          _stepResults.add(false);
        });
      }
    }
  }

  bool get _failed => _stepResults.isNotEmpty && _stepResults.last == false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.champagneGold),
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
        title: Text('Verification Badge',
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: _hasBadge
          ? _buildBadgeEarned()
          : _sequence.isEmpty
              ? _buildIntro()
              : _failed
                  ? _buildFailed()
                  : _isSubmitting
                      ? _buildSubmitting()
                      : _buildChallengeStep(),
    );
  }

  // ── Intro ────────────────────────────────────────────────────
  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.horizontalMargin),
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
              border: Border.all(color: AppColors.goldBorder, width: 2),
            ),
            child: const Icon(Icons.verified_outlined,
                color: AppColors.champagneGold, size: 44),
          ),
          const SizedBox(height: AppDimensions.space32),
          const Text('Earn Your Badge',
              style: AppTypography.screenTitle, textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.space12),
          Text(
            'Complete 3 quick poses to prove you\'re real.\n'
            'Takes about 15 seconds.',
            style: AppTypography.body
                .copyWith(color: AppColors.slateMist, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space40),
          // Benefits
          ...[
            (Icons.verified_rounded, '3× more interest from matches'),
            (Icons.trending_up_rounded, 'Higher ranking in search results'),
            (Icons.shield_rounded, 'Gold badge on your profile'),
          ].map((b) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusChip),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child:
                          Icon(b.$1, color: AppColors.champagneGold, size: 16),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(child: Text(b.$2, style: AppTypography.body)),
                  ],
                ),
              )),
          if (_attemptsToday > 0)
            Text('${3 - _attemptsToday} attempts remaining today',
                style: AppTypography.caption.copyWith(
                    color: _attemptsToday >= 2
                        ? AppColors.softCoral
                        : AppColors.slateMist)),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton)),
              ),
              onPressed: _startVerification,
              child:
                  const Text('Start 3-Pose Check', style: AppTypography.button),
            ),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }

  // ── Challenge Step ───────────────────────────────────────────
  Widget _buildChallengeStep() {
    final challenge = _sequence[_currentStep];
    final IconData icon;
    switch (challenge) {
      case VerificationChallenge.smile:
        icon = Icons.sentiment_satisfied_alt_rounded;
      case VerificationChallenge.turnLeft:
        icon = Icons.turn_slight_left_rounded;
      case VerificationChallenge.turnRight:
        icon = Icons.turn_slight_right_rounded;
      case VerificationChallenge.lookUp:
        icon = Icons.arrow_upward_rounded;
      case VerificationChallenge.lookDown:
        icon = Icons.arrow_downward_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.horizontalMargin),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Step progress
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final done = i < _stepResults.length && _stepResults[i];
              final current = i == _currentStep;
              return Container(
                width: 40,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.verifiedTeal
                      : current
                          ? AppColors.champagneGold
                          : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: AppDimensions.space12),
          Text('POSE ${_currentStep + 1} OF 3',
              style: AppTypography.sectionLabel
                  .copyWith(color: AppColors.champagneGold, letterSpacing: 2)),
          const SizedBox(height: AppDimensions.space32),
          // Challenge card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.space32),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.goldBorder, width: 1.5),
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.champagneGold.withValues(alpha: 0.12),
                        border: Border.all(
                            color:
                                AppColors.champagneGold.withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child:
                          Icon(icon, color: AppColors.champagneGold, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),
                Text(challenge.instruction,
                    style: AppTypography.screenTitle.copyWith(fontSize: 24),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppDimensions.space16),
                Text('Take a selfie while performing this action.',
                    style: AppTypography.caption.copyWith(height: 1.5),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const Spacer(flex: 2),
          if (_isProcessing)
            Column(
              children: [
                const CircularProgressIndicator(color: AppColors.champagneGold),
                const SizedBox(height: AppDimensions.space16),
                Text('Analysing pose...',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.champagneGold)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton)),
                ),
                icon: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.obsidianNight, size: 20),
                label: const Text('Capture', style: AppTypography.button),
                onPressed: _captureForStep,
              ),
            ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }

  // ── Failed ──────────────────────────────────────────────────
  Widget _buildFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.horizontalMargin),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softCoral.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.softCoral, width: 2.5),
            ),
            child: const Icon(Icons.close_rounded,
                color: AppColors.softCoral, size: 50),
          ),
          const SizedBox(height: AppDimensions.space32),
          const Text('Pose Not Detected',
              style: AppTypography.screenTitle, textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.space12),
          Text(
            _errorMessage ??
                'Please try again with good lighting and a clear background.',
            style: AppTypography.body
                .copyWith(color: AppColors.slateMist, height: 1.6),
            textAlign: TextAlign.center,
          ),
          if (_attemptsToday < 3) ...[
            const SizedBox(height: AppDimensions.space12),
            Text('${3 - _attemptsToday} attempts remaining today',
                style: AppTypography.caption),
          ],
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton)),
              ),
              onPressed: _attemptsToday < 3 ? _startVerification : null,
              child: Text(_attemptsToday < 3 ? 'Try Again' : 'Try Tomorrow',
                  style: AppTypography.button),
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Maybe Later', style: AppTypography.buttonSecondary),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }

  // ── Submitting ──────────────────────────────────────────────
  Widget _buildSubmitting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.champagneGold.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppColors.champagneGold.withValues(alpha: 0.3),
                      width: 2),
                ),
                child: const Icon(Icons.verified_outlined,
                    color: AppColors.champagneGold, size: 44),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space32),
          Text('Saving Badge...',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.champagneGold)),
          const SizedBox(height: AppDimensions.space12),
          const Text('All 3 poses verified!', style: AppTypography.caption),
          const SizedBox(height: AppDimensions.space32),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.surfaceGlass,
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.champagneGold.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge Earned ────────────────────────────────────────────
  Widget _buildBadgeEarned() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.horizontalMargin),
      child: Column(
        children: [
          const Spacer(flex: 2),
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _successController..forward(),
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.champagneGold.withValues(alpha: 0.3),
                    AppColors.champagneGold.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: AppColors.champagneGold, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.champagneGold.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 5),
                ],
              ),
              child: const Icon(Icons.verified_rounded,
                  color: AppColors.champagneGold, size: 56),
            ),
          ),
          const SizedBox(height: AppDimensions.space32),
          const Text('Badge Earned!',
              style: AppTypography.screenTitle, textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.space12),
          Text(
            'Your profile now displays a gold verification badge.\n'
            'Other members can see you\'ve been verified.',
            style: AppTypography.body
                .copyWith(color: AppColors.slateMist, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.champagneGold),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done',
                  style: AppTypography.buttonSecondary
                      .copyWith(color: AppColors.champagneGold)),
            ),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}
