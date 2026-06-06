import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/services/supabase_service.dart';
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
  List<_Viewer> _loadedViewers = [];
  bool _isLoading = false;

  // Generate 10 mock viewers with staggered timestamps as fallback
  static final List<_Viewer> _mockViewers = () {
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

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isInitialized) {
      _loadViews();
    } else {
      _loadedViewers = _mockViewers;
    }
  }

  Future<void> _loadViews() async {
    setState(() => _isLoading = true);
    try {
      final authState = context.read<AuthCubit>().state;
      final myUserId = authState is AuthAuthenticated ? authState.userId : null;
      if (myUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Get my profile ID
      final myProfileRes = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('user_id', myUserId)
          .single();
      final myProfileId = myProfileRes['id'] as String;

      // 2. Fetch views
      final response = await SupabaseService.client
          .from('profile_views')
          .select('''
            viewed_at,
            viewer:profiles!viewer_profile_id (
              id,
              user_id,
              first_name,
              last_name,
              date_of_birth,
              gender,
              is_verified,
              bio,
              photo_privacy,
              sect,
              deen_level,
              city_id,
              cities:cities!city_id (name)
            )
          ''')
          .eq('viewed_profile_id', myProfileId)
          .order('viewed_at', ascending: false)
          .limit(50);

      final List<dynamic> rows = response as List<dynamic>;
      final List<_Viewer> viewersList = [];

      for (final row in rows) {
        final viewedAt = DateTime.tryParse(row['viewed_at'] as String) ?? DateTime.now();
        final viewerData = row['viewer'] as Map<String, dynamic>?;
        if (viewerData == null) continue;

        final dobStr = viewerData['date_of_birth'] as String?;
        final dob = dobStr != null ? DateTime.tryParse(dobStr) : null;
        final age = dob != null ? DateTime.now().difference(dob).inDays ~/ 365 : 25;

        final citiesData = viewerData['cities'];
        final cityName = citiesData is List && citiesData.isNotEmpty
            ? (citiesData.first as Map<String, dynamic>)['name'] as String? ?? 'Unknown'
            : citiesData is Map<String, dynamic>
                ? citiesData['name'] as String? ?? 'Unknown'
                : 'Unknown';

        final viewerProfileId = viewerData['id'] as String;

        final profile = MockProfile(
          id: viewerProfileId,
          firstName: viewerData['first_name'] as String? ?? 'Noor User',
          lastNameInitial: ((viewerData['last_name'] as String?) ?? '').isNotEmpty
              ? (viewerData['last_name'] as String)[0]
              : '',
          age: age,
          cityName: cityName,
          sect: ((viewerData['sect'] as String?) ?? 'sunni').toUpperCase(),
          deenLevel: (viewerData['deen_level'] as String?) ?? 'moderate',
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
        });
      }
    } catch (e) {
      debugPrint('[ProfileViewsScreen] Error loading views: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
      body: _isLoading
          ? const _ShimmerLoader()
          : _loadedViewers.isEmpty
              ? const _EmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Text(
                        '${_loadedViewers.length} people viewed your profile this week',
                        style: AppTypography.screenTitle.copyWith(fontSize: 18),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        itemCount:      _loadedViewers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimensions.space8),
                        itemBuilder: (context, i) {
                          final viewer = _loadedViewers[i];
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

// ── Shimmer loader ───────────────────────────────────────────

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
                decoration: const BoxDecoration(
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

// ── Empty State ──────────────────────────────────────────────

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
              child: const Icon(
                Icons.remove_red_eye_outlined,
                color: AppColors.slateMist,
                size: 48,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            Text(
              'No Views Yet',
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space12),
            const Text(
              'Keep editing and improving your profile\nto get discovered by matches.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
