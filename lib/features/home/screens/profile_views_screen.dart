// lib/features/home/screens/profile_views_screen.dart
// ============================================================
// NOOR — Profile Views Screen (Feature 10)
// Shows 10 mock viewers with timestamps + "Send Interest" CTA.
// Navigate from MyProfileScreen "👁 Profile Views" row.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Mock viewer model ─────────────────────────────────────────

class _Viewer {
  const _Viewer({required this.profile, required this.viewedAt});
  final MockProfile profile;
  final DateTime    viewedAt;
}

// ── Screen ────────────────────────────────────────────────────

class ProfileViewsScreen extends StatefulWidget {
  const ProfileViewsScreen({super.key});

  @override
  State<ProfileViewsScreen> createState() => _ProfileViewsScreenState();
}

class _ProfileViewsScreenState extends State<ProfileViewsScreen> {
  final Set<String> _interestSent = {};

  // Generate 10 mock viewers with staggered timestamps
  static final List<_Viewer> _viewers = () {
    final now = DateTime.now();
    final offsets = [
      const Duration(minutes: 15),
      const Duration(minutes: 45),
      const Duration(hours: 2),
      const Duration(hours: 5),
      const Duration(hours: 11),
      const Duration(hours: 18),
      const Duration(days: 1, hours: 3),
      const Duration(days: 1, hours: 14),
      const Duration(days: 2, hours: 6),
      const Duration(days: 2, hours: 20),
    ];
    return List.generate(
      offsets.length,
      (i) => _Viewer(
        profile:  kMockProfiles[i % kMockProfiles.length],
        viewedAt: now.subtract(offsets[i]),
      ),
    );
  }();

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor:  AppColors.obsidianNight,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color:  AppColors.surfaceGlass,
              shape:  BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.pearlWhite,
              size:  AppDimensions.iconSizeMedium,
            ),
          ),
        ),
        title: Text('Profile Views',
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              '${_viewers.length} people viewed your profile this week',
              style: AppTypography.screenTitle.copyWith(fontSize: 18),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              itemCount:      _viewers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimensions.space8),
              itemBuilder: (context, i) {
                final viewer = _viewers[i];
                final p      = viewer.profile;
                final sent   = _interestSent.contains(p.id);
                return _ViewerTile(
                  firstName:        p.firstName,
                  lastNameInitial:  p.lastNameInitial,
                  age:              p.age,
                  city:             p.cityName,
                  timeLabel:        _timeLabel(viewer.viewedAt),
                  isVerified:       p.isVerified,
                  isInterestSent:   sent,
                  onSendInterest:   sent ? null : () {
                    HapticFeedback.mediumImpact();
                    setState(() => _interestSent.add(p.id));
                    context.read<InterestsCubit>().sendInterest(p);
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Row(children: [
                            const Icon(Icons.favorite_rounded,
                                color: AppColors.champagneGold, size: 16),
                            const SizedBox(width: 8),
                            Text('Interest sent to ${p.firstName}',
                                style: AppTypography.body),
                          ]),
                          backgroundColor: AppColors.surfaceGlassHover,
                          behavior:        SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusButton),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Viewer tile ───────────────────────────────────────────────

class _ViewerTile extends StatelessWidget {
  const _ViewerTile({
    required this.firstName,
    required this.lastNameInitial,
    required this.age,
    required this.city,
    required this.timeLabel,
    required this.isVerified,
    required this.isInterestSent,
    required this.onSendInterest,
  });

  final String       firstName;
  final String       lastNameInitial;
  final int          age;
  final String       city;
  final String       timeLabel;
  final bool         isVerified;
  final bool         isInterestSent;
  final VoidCallback? onSendInterest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar circle
          Stack(
            children: [
              Container(
                width:  52,
                height: 52,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  color:  AppColors.surfaceGlassHover,
                  border: Border.all(
                    color: AppColors.goldBorder,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.slateMist,
                  size:  24,
                ),
              ),
              if (isVerified)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width:  18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.verifiedTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppDimensions.space14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName $lastNameInitial.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  '$age · $city',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space4),
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        size: 12, color: AppColors.slateMist),
                    const SizedBox(width: 4),
                    Text(timeLabel, style: AppTypography.caption),
                  ],
                ),
              ],
            ),
          ),

          // Interest button
          const SizedBox(width: AppDimensions.space8),
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            child: isInterestSent
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space12,
                        vertical:   AppDimensions.space8),
                    decoration: BoxDecoration(
                      color:        AppColors.champagneGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border:       Border.all(color: AppColors.goldBorder),
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: AppColors.champagneGold, size: 18),
                  )
                : GestureDetector(
                    onTap: onSendInterest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space12,
                          vertical:   AppDimensions.space8),
                      decoration: BoxDecoration(
                        color:        AppColors.champagneGold,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      child: const Icon(Icons.favorite_border_rounded,
                          color: AppColors.obsidianNight, size: 18),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
