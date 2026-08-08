import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Viewer row model
class _Viewer {
  const _Viewer({required this.profile, required this.viewedAt});
  final DiscoveryProfile profile;
  final DateTime viewedAt;
}

// Screen
class ProfileViewsScreen extends StatefulWidget {
  const ProfileViewsScreen({super.key});

  @override
  State<ProfileViewsScreen> createState() => _ProfileViewsScreenState();
}

class _ProfileViewsScreenState extends State<ProfileViewsScreen> {
  List<_Viewer> _loadedViewers = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<SubscriptionCubit>().state.isSubscribed) {
        _loadViews();
      }
    });
  }

  Future<void> _loadViews() async {
    if (_isLoading || _hasLoaded) return;
    setState(() => _isLoading = true);
    try {
      final authState = context.read<AuthCubit>().state;
      final myUserId = authState is AuthAuthenticated ? authState.userId : null;
      if (myUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await SupabaseService.client.rpc(
        'get_my_profile_viewers',
        params: {'p_limit': 50},
      );

      final List<dynamic> rows = response as List<dynamic>;
      final List<_Viewer> viewersList = [];

      for (final row in rows) {
        final viewerData = Map<String, dynamic>.from(row as Map);
        final viewedAt = DateTime.tryParse(
              viewerData['viewed_at']?.toString() ?? '',
            ) ??
            DateTime.now();
        final viewerUserId = (viewerData['viewer_user_id'] as String?)?.trim();
        final firstName = (viewerData['first_name'] as String?)?.trim();
        final dobStr = viewerData['date_of_birth']?.toString();
        final dob = dobStr != null ? DateTime.tryParse(dobStr) : null;
        final age = dob == null ? null : _ageFromDob(dob);
        if (viewerUserId == null ||
            viewerUserId.isEmpty ||
            firstName == null ||
            firstName.isEmpty ||
            age == null ||
            age < 18) {
          continue;
        }

        final cityName = viewerData['city_name']?.toString().trim();

        final lastName = (viewerData['last_name'] as String?)?.trim();

        final profile = DiscoveryProfile(
          id: viewerUserId,
          firstName: firstName,
          lastNameInitial:
              lastName != null && lastName.isNotEmpty ? lastName[0] : '',
          lastName: lastName,
          age: age,
          cityName: cityName == null || cityName.isEmpty
              ? 'Location private'
              : cityName,
          sect: (viewerData['sect'] as String?)?.toUpperCase(),
          deenLevel: viewerData['deen_level'] as String?,
          isVerified: viewerData['is_verified'] as bool? ?? false,
          bio: viewerData['bio'] as String? ?? '',
          gender: viewerData['gender'] as String?,
        );

        viewersList.add(_Viewer(profile: profile, viewedAt: viewedAt));
      }

      if (mounted) {
        setState(() {
          _loadedViewers = viewersList;
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[ProfileViewsScreen] Error loading views: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    }
  }

  String _timeLabel(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return context.uiMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return context.uiHoursAgo(diff.inHours);
    if (diff.inDays == 1) return context.uiCopy('Yesterday');
    return context.uiDaysAgo(diff.inDays);
  }

  int _ageFromDob(DateTime dob) {
    final today = DateTime.now();
    var years = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      years--;
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final interests = context.watch<InterestsCubit>().state;
    return BlocConsumer<SubscriptionCubit, SubscriptionState>(
      listenWhen: (previous, current) =>
          previous.isSubscribed != current.isSubscribed,
      listener: (context, subscription) {
        if (subscription.isSubscribed) _loadViews();
      },
      builder: (context, subscription) => Scaffold(
        backgroundColor: AppColors.obsidianNight,
        appBar: AppBar(
          backgroundColor: AppColors.obsidianNight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.pearlWhite,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
          ),
          title: UiText(context.uiCopy('Profile Views'),
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
        ),
        body: subscription.isLoading && !subscription.isSubscribed
            ? const _ShimmerLoader()
            : !subscription.isSubscribed
                ? _PremiumViewerGate(
                    onUpgrade: () => context.push(AppRoutes.subscription),
                  )
                : _isLoading
                    ? const _ShimmerLoader()
                    : _loadedViewers.isEmpty
                        ? const _EmptyState()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 8, 24, 16),
                                child: UiText(
                                  '${_loadedViewers.length} people viewed your profile this week',
                                  style: AppTypography.screenTitle
                                      .copyWith(fontSize: 18),
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 40),
                                  itemCount: _loadedViewers.length,
                                  separatorBuilder: (_, __) => const SizedBox(
                                      height: AppDimensions.space8),
                                  itemBuilder: (context, i) {
                                    final viewer = _loadedViewers[i];
                                    final p = viewer.profile;
                                    final sent =
                                        interests.interactionWith(p.id) !=
                                            ProfileInteractionState.none;
                                    return _ViewerTile(
                                      displayName: p.displayName,
                                      age: p.age,
                                      city: p.cityName,
                                      timeLabel:
                                          _timeLabel(context, viewer.viewedAt),
                                      isVerified: p.isVerified,
                                      isInterestSent: sent,
                                      onSendInterest: sent
                                          ? null
                                          : () async {
                                              HapticFeedback.mediumImpact();
                                              final sent = await context
                                                  .read<InterestsCubit>()
                                                  .sendInterest(p);
                                              if (!context.mounted) return;
                                              if (!sent) {
                                                ScaffoldMessenger.of(context)
                                                  ..clearSnackBars()
                                                  ..showSnackBar(
                                                    SnackBar(
                                                      content: UiText(
                                                        context.uiCopy(
                                                            'Interest could not be sent. Check your limit and try again.'),
                                                      ),
                                                    ),
                                                  );
                                                return;
                                              }
                                              ScaffoldMessenger.of(context)
                                                ..clearSnackBars()
                                                ..showSnackBar(
                                                  SnackBar(
                                                    content: Row(children: [
                                                      Icon(
                                                          Icons
                                                              .favorite_rounded,
                                                          color: AppColors
                                                              .champagneGold,
                                                          size: 16),
                                                      const SizedBox(width: 8),
                                                      UiText(
                                                          'Interest sent to ${p.firstName}',
                                                          style: AppTypography
                                                              .body
                                                              .copyWith(
                                                            color: AppColors
                                                                .readableOn(
                                                              AppColors
                                                                  .surfaceGlassHover,
                                                            ),
                                                          )),
                                                    ]),
                                                    backgroundColor: AppColors
                                                        .surfaceGlassHover,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppDimensions
                                                                  .radiusButton),
                                                    ),
                                                    duration: const Duration(
                                                        seconds: 2),
                                                  ),
                                                );
                                            },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
      ),
    );
  }
}

class _PremiumViewerGate extends StatelessWidget {
  const _PremiumViewerGate({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.champagneGold.withValues(alpha: .1),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Icon(
                Icons.visibility_outlined,
                color: AppColors.champagneGold,
                size: 32,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            UiText(
              context.uiCopy('Your weekly count stays visible'),
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space10),
            UiText(
              'Premium reveals the people behind those views. Silarah never calls interests “likes” or creates a second, confusing action.',
              style: AppTypography.bodyMuted.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUpgrade,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: UiText(context.uiCopy('Explore Premium')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shimmer loader
class _ShimmerLoader extends StatelessWidget {
  const _ShimmerLoader();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space8),
      itemBuilder: (_, __) => Container(
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceGlassHover,
                ),
              ),
              const SizedBox(width: AppDimensions.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 160,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlassHover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.space24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder, width: 2),
                color: AppColors.surfaceGlass,
              ),
              child: Icon(
                Icons.remove_red_eye_outlined,
                color: AppColors.slateMist,
                size: 48,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            UiText(
              context.uiCopy('No Views Yet'),
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space12),
            UiText(
              context.uiCopy(
                  'Keep editing and improving your profile\nto get discovered by matches.'),
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Viewer tile
class _ViewerTile extends StatelessWidget {
  const _ViewerTile({
    required this.displayName,
    required this.age,
    required this.city,
    required this.timeLabel,
    required this.isVerified,
    required this.isInterestSent,
    required this.onSendInterest,
  });

  final String displayName;
  final int age;
  final String city;
  final String timeLabel;
  final bool isVerified;
  final bool isInterestSent;
  final VoidCallback? onSendInterest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar circle
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceGlassHover,
                  border: Border.all(
                    color: AppColors.goldBorder,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.slateMist,
                  size: 24,
                ),
              ),
              if (isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.verifiedTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded,
                        color: AppColors.pearlWhite, size: 12),
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
                UiText(
                  displayName,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  '$age · $city',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space4),
                Row(
                  children: [
                    Icon(Icons.remove_red_eye_outlined,
                        size: 12, color: AppColors.slateMist),
                    const SizedBox(width: 4),
                    UiText(timeLabel, style: AppTypography.caption),
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
                        vertical: AppDimensions.space8),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: Icon(Icons.favorite_rounded,
                        color: AppColors.champagneGold, size: 18),
                  )
                : GestureDetector(
                    onTap: onSendInterest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space12,
                          vertical: AppDimensions.space8),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      child: Icon(Icons.favorite_border_rounded,
                          color: AppColors.obsidianNight, size: 18),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
