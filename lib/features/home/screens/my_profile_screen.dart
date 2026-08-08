// lib/features/home/screens/my_profile_screen.dart
// ============================================================
// SILARAH — My Profile Screen
// Self-view: completeness bar, boost section, profile views
// row, saved profiles, settings sections, sign out.
// ============================================================

import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/cubits/account_standing/account_standing_cubit.dart';
import '../../../core/cubits/account_standing/account_standing_state.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/authorized_profile_service.dart';
import '../../../core/services/kyc_verification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'profile_views_screen.dart';
import 'profile_detail_screen.dart';
import 'notifications_screen.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/selfie_verification_service.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/profile_view_service.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../../core/utils/silarah_compute.dart';
import '../../onboarding/screens/photo_upload_screen.dart';
import '../widgets/notification_bell_button.dart';

// ── Completeness score ────────────────────────────────────────

({int score, String? nudge}) _calcCompleteness(
  OnboardingData d, {
  required int approvedPhotoCount,
}) {
  int score = 0;
  final hasPrimaryPhoto = approvedPhotoCount > 0;
  if (hasPrimaryPhoto) score += 25;
  final hasBio = (d.bio?.length ?? 0) >= 50;
  if (hasBio) score += 15;
  final hasIslamic = d.sect != null && d.deenLevel != null;
  if (hasIslamic) score += 15;
  final hasEduPro = (d.educationLabel != null || d.educationRank != null) &&
      (d.profession?.isNotEmpty ?? false);
  if (hasEduPro) score += 10;
  final hasFamily = d.familyType != null;
  if (hasFamily) score += 10;
  final hasPartnerPrefs =
      d.preferredAgeMin != null && d.preferredAgeMax != null;
  if (hasPartnerPrefs) score += 10;
  final hasSecondPhoto = approvedPhotoCount >= 2;
  if (hasSecondPhoto) score += 8;
  final hasIncome = d.incomeBracketId != null;
  if (hasIncome) score += 4;
  final hasLangs = d.languages != null && d.languages!.isNotEmpty;
  if (hasLangs) score += 3;

  String? nudge;
  if (!hasPrimaryPhoto) {
    nudge = 'Add a profile photo to reach ${score + 25}%';
  } else if (!hasBio) {
    nudge = 'Add a bio to reach ${score + 15}%';
  } else if (!hasIslamic) {
    nudge = 'Complete Islamic identity to reach ${score + 15}%';
  } else if (!hasEduPro) {
    nudge = 'Add education & profession to reach ${score + 10}%';
  } else if (!hasFamily) {
    nudge = 'Add family background to reach ${score + 10}%';
  } else if (!hasPartnerPrefs) {
    nudge = 'Set partner preferences to reach ${score + 10}%';
  } else if (!hasSecondPhoto) {
    nudge = 'Add a second photo to reach ${score + 8}%';
  } else if (!hasIncome) {
    nudge = 'Add income range to reach ${score + 4}%';
  } else if (!hasLangs) {
    nudge = 'Add languages to reach ${score + 3}%';
  }

  return (score: score.clamp(0, 100), nudge: nudge);
}

// ── Screen ────────────────────────────────────────────────────

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<DiscoveryProfile> _savedProfiles = [];
  bool _guardianEnabled = false;
  bool _hasVerificationBadge = false;
  bool _verificationLoading = true;
  bool _trustStateLoading = true;
  bool _emailVerified = false;
  KycVerificationStatus _kycStatus = KycVerificationStatus.notStarted;
  String _kycAssuranceLevel = 'none';
  String? _accountEmail;
  String? _primaryPhotoUrl;
  int _approvedPhotoCount = 0;
  bool _photoRefreshInFlight = false;
  bool _profilePreviewOpening = false;
  bool _profileRefreshInFlight = false;
  DateTime? _lastProfileRefreshAt;
  static const _profileFreshness = Duration(minutes: 5);

  int _viewCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshProfileFromDb());
    _loadBookmarks();
  }

  @override
  void didUpdateWidget(covariant MyProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_refreshProfileFromDb(force: true));
      unawaited(_loadBookmarks(force: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshProfileFromDb());
      unawaited(_loadViewsCount());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadBookmarks({bool force = false}) async {
    try {
      final ids = await BookmarkService.load(force: force);
      await _loadSavedProfiles(ids);
    } catch (_) {
      if (mounted) setState(() => _savedProfiles = []);
    }
  }

  Future<void> _loadSavedProfiles(Set<String> ids) async {
    if (ids.isEmpty || !SupabaseService.isInitialized) {
      if (mounted) setState(() => _savedProfiles = []);
      return;
    }

    try {
      final mappedRows = await AuthorizedProfileService.load(ids.take(20));

      final profileIds =
          mappedRows.map((row) => row['id']?.toString()).whereType<String>();
      if (profileIds.isNotEmpty) {
        final photos = await SupabaseService.client
            .from('photos')
            .select('profile_id, blurhash')
            .inFilter('profile_id', profileIds.toList())
            .eq('status', 'active')
            .eq('admin_approved', true)
            .eq('nsfw_cleared', true)
            .order('order_index');

        final photosByProfile = <String, List<Map<String, dynamic>>>{};
        for (final photo in photos as List<dynamic>) {
          final mapped = Map<String, dynamic>.from(photo as Map);
          final profileId = mapped['profile_id']?.toString();
          if (profileId == null) continue;
          photosByProfile.putIfAbsent(profileId, () => []).add(mapped);
        }

        final ownersWithPhotos = mappedRows
            .where((row) =>
                photosByProfile[row['id']?.toString()]?.isNotEmpty == true)
            .map((row) => row['user_id']?.toString())
            .whereType<String>()
            .toList(growable: false);
        final signedUrls =
            await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
          ownerUserIds: ownersWithPhotos,
        );
        for (final row in mappedRows) {
          final profileId = row['id']?.toString();
          final profilePhotos =
              profileId == null ? null : photosByProfile[profileId];
          row['photo_count'] = profilePhotos?.length ?? 0;
          if (profilePhotos?.isNotEmpty == true) {
            final ownerUserId = row['user_id']?.toString();
            if (ownerUserId != null && ownerUserId.isNotEmpty) {
              row['photo_url'] = signedUrls[ownerUserId];
              row['blurhash'] = profilePhotos!.first['blurhash'];
            }
          }
        }
      }

      final profiles = mappedRows.map(mapDbRowToDiscoveryProfile).toList();
      if (mounted) setState(() => _savedProfiles = profiles);
    } catch (_) {
      if (mounted) setState(() => _savedProfiles = []);
    }
  }

  Future<void> _loadGuardian() async {
    if (SupabaseService.isInitialized) {
      final info = await WaliModeService.instance.getMyGuardianInfo();
      if (mounted) setState(() => _guardianEnabled = info != null);
    }
  }

  Future<void> _loadVerificationBadge() async {
    var hasBadge = false;
    if (SupabaseService.isInitialized) {
      try {
        hasBadge = await SelfieVerificationService.instance.hasBadge();
      } catch (_) {
        hasBadge = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _hasVerificationBadge = hasBadge;
      _verificationLoading = false;
    });
  }

  Future<void> _openVerification() async {
    await context.push(AppRoutes.badgeVerification);
    if (mounted) await _loadVerificationBadge();
  }

  Future<void> _openIdentityVerification() async {
    await context.push(AppRoutes.verify);
    if (mounted) await _loadTrustState();
  }

  Future<void> _openEditProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: AppDimensions.durationReveal,
        reverseTransitionDuration: AppDimensions.durationTransition,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: const EditProfileScreen(),
        ),
      ),
    );
    if (changed == true && mounted) await _refreshProfileFromDb(force: true);
  }

  Future<void> _openManagePhotos() async {
    final saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: AppDimensions.durationReveal,
        reverseTransitionDuration: AppDimensions.durationTransition,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: const PhotoUploadScreen(returnToPreviousOnSave: true),
        ),
      ),
    );
    if (saved == true && mounted) {
      await _refreshProfileFromDb(force: true);
    }
  }

  Future<void> _openOwnProfilePreview() async {
    if (_profilePreviewOpening) return;
    setState(() => _profilePreviewOpening = true);
    try {
      await _performOpenOwnProfilePreview();
    } finally {
      if (mounted) setState(() => _profilePreviewOpening = false);
    }
  }

  Future<void> _performOpenOwnProfilePreview() async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!mounted || userId == null) return;
    Map<int, String> photoSlots;
    try {
      photoSlots = await ProfilePhotoService.instance.getMyPhotoSlots();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText(context
              .uiCopy('Your photo gallery could not be opened. Try again.')),
        ),
      );
      return;
    }
    if (!mounted) return;
    final orderedPhotoUrls = photoSlots.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final galleryUrls = orderedPhotoUrls
        .map((entry) => entry.value)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    final refreshedPhotoUrl = galleryUrls.isEmpty ? null : galleryUrls.first;
    if (refreshedPhotoUrl != null && refreshedPhotoUrl.isNotEmpty) {
      setState(() => _primaryPhotoUrl = refreshedPhotoUrl);
    }
    final data = context.read<OnboardingCubit>().currentData;
    final lastName = data.lastName?.trim() ?? '';
    final profile = DiscoveryProfile(
      id: userId,
      firstName: data.firstName?.trim().isNotEmpty == true
          ? data.firstName!.trim()
          : 'Your profile',
      lastNameInitial: lastName.isEmpty ? '' : lastName.characters.first,
      lastName: lastName.isEmpty ? null : lastName,
      age: data.age ?? 18,
      cityName: data.cityName?.trim().isNotEmpty == true
          ? data.cityName!.trim()
          : 'Location not set',
      countryCode: data.countryCode,
      sect: data.sect?.name,
      deenLevel: data.deenLevel?.name,
      photoUrl: refreshedPhotoUrl ?? _primaryPhotoUrl,
      photoUrls: galleryUrls,
      photoCount: galleryUrls.length,
      photoPrivacy: data.photoPrivacy == PhotoPrivacy.mutualOnly
          ? 'mutual_only'
          : data.photoPrivacy == PhotoPrivacy.requestOnly
              ? 'request_only'
              : 'public',
      isVerified: _kycStatus == KycVerificationStatus.approved,
      occupation: data.profession,
      education: data.educationLabel,
      bio: data.bio,
      languages: data.languages,
      maritalStatus: data.maritalStatus?.name,
      familyType: data.familyType?.name,
      interests: data.interests,
      partnerAgeMin: data.preferredAgeMin,
      partnerAgeMax: data.preferredAgeMax,
      partnerSect: data.preferredSect,
      partnerDeenLevel: data.preferredDeenLevel,
      partnerEducationMinRank: data.minEducationRank,
      heightCm: data.heightCm,
      complexion: data.complexion,
      motherTongue: data.motherTongue,
      smokingHabit: data.smokingHabit,
      vapingHabit: data.vapingHabit,
      hookahHabit: data.hookahHabit,
      isGuardianProfile: data.isGuardianMode,
      community: data.community,
      dietType: data.dietType,
      livingExpectation: data.livingExpectation,
      quranMemorization: data.quranMemorization,
      religiousEducation: data.religiousEducation,
      marriageTimeline: data.marriageTimeline,
      willingToRelocate: data.willingToRelocate,
      gender: data.gender?.name,
      hasChildren: data.hasChildren ?? false,
      incomeBracket: data.incomeBracketLabel,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          profile: profile,
          heroTag: 'own-profile-preview-$userId',
          isOwnProfile: true,
          onEditOwnProfile: () {
            Navigator.of(context).pop();
            unawaited(_openEditProfile());
          },
          onManageOwnPhotos: () {
            Navigator.of(context).pop();
            unawaited(_openManagePhotos());
          },
        ),
      ),
    );
  }

  Future<void> _loadTrustState() async {
    if (!SupabaseService.isInitialized) return;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) return;

    try {
      final kyc = await KycVerificationService.instance.fetchStatus();
      final authUser = SupabaseService.client.auth.currentUser;
      if (!mounted) return;
      setState(() {
        _kycStatus = kyc.status;
        _kycAssuranceLevel = kyc.assuranceLevel;
        _accountEmail = authUser?.email;
        _emailVerified = authUser?.emailConfirmedAt != null;
        _trustStateLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _trustStateLoading = false);
    }
  }

  Future<void> _refreshProfileFromDb({bool force = false}) async {
    if (!SupabaseService.isInitialized || _profileRefreshInFlight) return;
    final lastRefresh = _lastProfileRefreshAt;
    if (!force &&
        lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _profileFreshness) {
      return;
    }
    _profileRefreshInFlight = true;
    try {
      await context.read<OnboardingCubit>().refreshProfileFromDb(force: force);
      await Future.wait([
        _loadPrimaryPhoto(),
        _loadApprovedPhotoCount(),
        _loadViewsCount(),
        _loadGuardian(),
        _loadVerificationBadge(),
        _loadTrustState(),
      ]);
      _lastProfileRefreshAt = DateTime.now();
    } finally {
      _profileRefreshInFlight = false;
    }
  }

  Future<void> _loadPrimaryPhoto() async {
    try {
      final url = await ProfilePhotoService.instance.getPrimaryPhotoUrl();
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _primaryPhotoUrl = url);
      }
    } catch (_) {}
  }

  Future<void> _recoverPrimaryPhoto(String failedUrl) async {
    if (_photoRefreshInFlight || failedUrl != _primaryPhotoUrl) return;
    _photoRefreshInFlight = true;
    try {
      final refreshedUrl =
          await ProfilePhotoService.instance.getPrimaryPhotoUrl(
        forceRefresh: true,
      );
      if (!mounted || refreshedUrl == null || refreshedUrl.isEmpty) return;
      setState(() => _primaryPhotoUrl = refreshedUrl);
    } finally {
      _photoRefreshInFlight = false;
    }
  }

  Future<void> _loadViewsCount() async {
    try {
      final count = await ProfileViewService.instance.weeklyDistinctCount();
      if (mounted) {
        setState(() => _viewCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadApprovedPhotoCount() async {
    try {
      final myUserId = await SupabaseService.currentUserIdOrRefresh();
      if (myUserId == null) return;
      final profile = await SupabaseService.client
          .from('my_profile_private')
          .select('id')
          .eq('user_id', myUserId)
          .maybeSingle();
      final profileId = profile?['id']?.toString();
      if (profileId == null || profileId.isEmpty) return;
      final rows = await SupabaseService.client
          .from('photos')
          .select('id')
          .eq('profile_id', profileId)
          .eq('status', 'active')
          .eq('admin_approved', true)
          .eq('nsfw_cleared', true);
      if (mounted) setState(() => _approvedPhotoCount = rows.length);
    } catch (_) {
      if (mounted) setState(() => _approvedPhotoCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(context.uiCopy('Profile'),
                        style: AppTypography.screenTitle),
                    const SizedBox(height: 2),
                    UiText('Your presence on Silarah',
                        style: AppTypography.caption),
                  ],
                ),
                const Spacer(),
                // Notifications
                NotificationBellButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                // Settings
                SilarahPressable(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                    if (!context.mounted) return;
                    await context.read<AccountStandingCubit>().refresh();
                    await _loadTrustState();
                  },
                  child: Container(
                    width: AppDimensions.minTouchTarget,
                    height: AppDimensions.minTouchTarget,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: AppColors.slateMist,
                      size: AppDimensions.iconSizeLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.space28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<AccountStandingCubit, AccountStandingState>(
              builder: (context, standing) => _ProfileLifecycleCard(
                standing: standing,
                onResume: () =>
                    context.read<AccountStandingCubit>().resumeProfile(),
                onContactSupport: () => context.push(AppRoutes.helpSupport),
                onManagePhotos: _openManagePhotos,
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Profile card preview (live completeness)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<OnboardingCubit, OnboardingState>(
              builder: (context, _) {
                final data = context.read<OnboardingCubit>().currentData;
                final result = _calcCompleteness(
                  data,
                  approvedPhotoCount: _approvedPhotoCount,
                );
                return _ProfilePreviewCard(
                  score: result.score,
                  nudge: result.nudge,
                  data: data,
                  guardianEnabled: _guardianEnabled,
                  hasVerificationBadge: _hasVerificationBadge,
                  verificationLoading: _verificationLoading,
                  onVerify: _openVerification,
                  primaryPhotoUrl: _primaryPhotoUrl,
                  onPhotoLoadFailed: _recoverPrimaryPhoto,
                );
              },
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ProfilePrimaryActions(
              onEdit: _openEditProfile,
              onPreview: _openOwnProfilePreview,
              previewOpening: _profilePreviewOpening,
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _TrustCenterCard(
              loading: _trustStateLoading,
              kycStatus: _kycStatus,
              kycAssuranceLevel: _kycAssuranceLevel,
              hasFaceBadge: _hasVerificationBadge,
              email: _accountEmail,
              emailVerified: _emailVerified,
              onIdentityVerification: _openIdentityVerification,
              onFaceVerification: _openVerification,
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Profile Views row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SilarahPressable(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileViewsScreen(),
                  ),
                );
                if (mounted) await _loadViewsCount();
              },
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space8),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Icon(
                        Icons.remove_red_eye_outlined,
                        color: AppColors.champagneGold,
                        size: AppDimensions.iconSizeMedium,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(context.uiCopy('Profile Views'),
                              style: AppTypography.bodyMedium),
                          UiText(context.uiCopy('This week'),
                              style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: UiText(
                        '$_viewCount',
                        style: AppTypography.captionMedium
                            .copyWith(color: AppColors.obsidianNight),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Subscription card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SubscriptionCard(),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Referral Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SilarahPressable(
              onTap: () => context.push(AppRoutes.referral),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(
                      color: AppColors.goldBorder.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.champagneGold.withValues(alpha: 0.02),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space8),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.champagneGold,
                        size: AppDimensions.iconSizeMedium,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(context.uiCopy('Refer a Friend'),
                              style: AppTypography.bodyMedium),
                          UiText(
                              context.uiCopy('Get 7 days of Premium for free'),
                              style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // ── Boost Section ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _BoostSection(),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Saved profiles section — always shown (empty state if none)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SavedProfilesSection(
              savedProfiles: _savedProfiles,
              onChanged: _loadBookmarks,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _IFoundMyMatchButton(),
          ),
          const SizedBox(height: AppDimensions.space16),

          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.softCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: Icon(Icons.logout_rounded,
                    color: AppColors.softCoral,
                    size: AppDimensions.iconSizeMedium),
                label: UiText(context.uiCopy('Sign Out'),
                    style: AppTypography.buttonSecondary
                        .copyWith(color: AppColors.softCoral)),
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

// ── Boost Section ─────────────────────────────────────────────

class _ProfilePrimaryActions extends StatelessWidget {
  const _ProfilePrimaryActions({
    required this.onEdit,
    required this.onPreview,
    required this.previewOpening,
  });

  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final bool previewOpening;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: SilarahPressable(
            semanticLabel: context.uiCopy('Edit your profile'),
            onTap: onEdit,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.champagneLight, AppColors.champagneGold],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.champagneGold.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded,
                      size: 19, color: AppColors.obsidianNight),
                  const SizedBox(width: AppDimensions.space8),
                  UiText(context.uiCopy('Edit profile'),
                      style: AppTypography.button),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.space10),
        Expanded(
          flex: 5,
          child: SilarahPressable(
            semanticLabel: context.uiCopy('View your public profile'),
            onTap: previewOpening ? null : onPreview,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (previewOpening)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.champagneGold,
                      ),
                    )
                  else
                    Icon(
                      Icons.visibility_outlined,
                      size: 19,
                      color: AppColors.champagneGold,
                    ),
                  const SizedBox(width: AppDimensions.space8),
                  Flexible(
                    child: UiText(context.uiCopy('View profile'),
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.buttonSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileLifecycleCard extends StatelessWidget {
  const _ProfileLifecycleCard({
    required this.standing,
    required this.onResume,
    required this.onContactSupport,
    required this.onManagePhotos,
  });

  final AccountStandingState standing;
  final VoidCallback onResume;
  final VoidCallback onContactSupport;
  final VoidCallback onManagePhotos;

  @override
  Widget build(BuildContext context) {
    final isBanned = standing.kind == AccountStandingKind.banned;
    final isSuspended = standing.kind == AccountStandingKind.suspended;
    final isDeactivated = standing.kind == AccountStandingKind.deactivated;
    final isPaused = standing.kind == AccountStandingKind.paused;
    final isActive = standing.kind == AccountStandingKind.active;
    final isRestricted = isBanned || isSuspended || isDeactivated;
    final needsPhoto = !standing.hasPublishedPhoto && !isRestricted;
    final color = isRestricted
        ? AppColors.softCoral
        : isActive && !needsPhoto
            ? AppColors.verifiedTeal
            : AppColors.champagneGold;
    final icon = isBanned
        ? Icons.block_rounded
        : isSuspended
            ? Icons.gpp_maybe_outlined
            : isDeactivated
                ? Icons.person_off_outlined
                : isPaused
                    ? Icons.pause_circle_outline_rounded
                    : needsPhoto
                        ? Icons.add_photo_alternate_outlined
                        : Icons.public_rounded;
    final title = isBanned
        ? 'Account banned'
        : isSuspended
            ? 'Profile suspended'
            : isDeactivated
                ? 'Profile deactivated'
                : isPaused
                    ? 'Profile paused'
                    : needsPhoto
                        ? 'Primary photo required'
                        : isActive
                            ? 'Live in discovery'
                            : 'Checking account status';
    final body = isBanned
        ? 'An enforced account restriction is active. Your profile is not shown and protected actions are unavailable. You can contact Support to appeal.'
        : isSuspended
            ? 'Your profile is hidden while the account is under review. This status remains here until the restriction is resolved.'
            : isDeactivated
                ? 'Your profile is not active. Support can guide you through restoring access.'
                : isPaused
                    ? standing.hasPublishedPhoto
                        ? 'You are hidden from discovery. Resume whenever you are ready—your profile information and matches remain intact.'
                        : 'Your profile is hidden and needs a safe primary photo before it can return to discovery.'
                    : needsPhoto
                        ? 'Add a primary photo that passes the safety scan to publish your profile.'
                        : isActive
                            ? 'Your profile is visible and eligible to appear in discovery.'
                            : 'We are confirming your current visibility with Silarah.';
    final actionLabel = isRestricted
        ? 'Contact support'
        : isPaused && standing.hasPublishedPhoto
            ? 'Resume profile'
            : needsPhoto
                ? 'Manage photos'
                : null;
    final action = isRestricted
        ? onContactSupport
        : isPaused && standing.hasPublishedPhoto
            ? onResume
            : needsPhoto
                ? onManagePhotos
                : null;

    return Semantics(
      liveRegion: true,
      label: '${context.uiCopy(title)}. ${context.uiCopy(body)}',
      child: AnimatedContainer(
        duration: AppDimensions.durationReveal,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UiText(
                  context.uiCopy('ACCOUNT STANDING'),
                  style: AppTypography.sectionLabel,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: UiText(
                    isRestricted
                        ? 'RESTRICTED'
                        : isActive && !needsPhoto
                            ? 'ACTIVE'
                            : 'ATTENTION',
                    style: AppTypography.badge.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(
                        title,
                        style: AppTypography.bodyMedium.copyWith(color: color),
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      UiText(
                        standing.errorMessage ?? body,
                        style: AppTypography.caption.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null && action != null) ...[
              const SizedBox(height: AppDimensions.space14),
              Align(
                alignment: Alignment.centerRight,
                child: SilarahPressable(
                  semanticLabel: actionLabel,
                  onTap: standing.updating ? null : action,
                  enabled: !standing.updating,
                  child: Container(
                    height: 42,
                    constraints: const BoxConstraints(minWidth: 142),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isRestricted ? Colors.transparent : color,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: color),
                    ),
                    child: standing.updating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isRestricted
                                  ? color
                                  : AppColors.obsidianNight,
                            ),
                          )
                        : UiText(
                            actionLabel,
                            style: AppTypography.captionMedium.copyWith(
                              color: isRestricted
                                  ? color
                                  : AppColors.obsidianNight,
                            ),
                          ),
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

class _TrustCenterCard extends StatelessWidget {
  const _TrustCenterCard({
    required this.loading,
    required this.kycStatus,
    required this.kycAssuranceLevel,
    required this.hasFaceBadge,
    required this.email,
    required this.emailVerified,
    required this.onIdentityVerification,
    required this.onFaceVerification,
  });

  final bool loading;
  final KycVerificationStatus kycStatus;
  final String kycAssuranceLevel;
  final bool hasFaceBadge;
  final String? email;
  final bool emailVerified;
  final VoidCallback onIdentityVerification;
  final VoidCallback onFaceVerification;

  @override
  Widget build(BuildContext context) {
    final identityVerified = kycStatus == KycVerificationStatus.approved;
    final identityPending = kycStatus == KycVerificationStatus.pendingReview;
    final isManualReview = kycAssuranceLevel == 'manual_document_review';
    final identityPresentation = switch (kycStatus) {
      KycVerificationStatus.approved => (
          status: 'ID reviewed',
          subtitle: isManualReview
              ? 'Document and selfie reviewed by Silarah'
              : 'Identity evidence reviewed',
          color: AppColors.verifiedTeal,
        ),
      KycVerificationStatus.pendingReview => (
          status: 'In review',
          subtitle: 'Submitted for a secure human review',
          color: AppColors.champagneGold,
        ),
      KycVerificationStatus.rejected => (
          status: 'Not approved',
          subtitle: 'Open to review the decision and available next steps',
          color: AppColors.softCoral,
        ),
      KycVerificationStatus.resubmitRequired => (
          status: 'Action needed',
          subtitle: 'New or clearer identity evidence is required',
          color: AppColors.softCoral,
        ),
      KycVerificationStatus.expired => (
          status: 'Expired',
          subtitle: 'Submit a current government-issued document',
          color: AppColors.champagneGold,
        ),
      KycVerificationStatus.notStarted => (
          status: 'Verify',
          subtitle: 'Match a government ID with your selfie',
          color: AppColors.champagneGold,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(context.uiCopy('Trust & identity'),
                          style: AppTypography.bodyMedium),
                      const SizedBox(height: 2),
                      UiText(
                          context.uiCopy(
                              'Independent checks that strengthen your profile'),
                          style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.cardBorder),
          _TrustRow(
            icon: Icons.badge_outlined,
            title: 'Government ID check',
            subtitle: identityPresentation.subtitle,
            status: identityPresentation.status,
            statusColor: identityPresentation.color,
            onTap: identityVerified || identityPending || loading
                ? null
                : onIdentityVerification,
          ),
          Divider(height: 1, indent: 56, color: AppColors.cardBorder),
          _TrustRow(
            icon: Icons.face_retouching_natural_outlined,
            title: 'On-device photo check',
            subtitle: hasFaceBadge
                ? 'Passive liveness check completed'
                : 'Checks photo readiness; not government ID',
            status: hasFaceBadge ? 'Completed' : 'Start',
            statusColor:
                hasFaceBadge ? AppColors.verifiedTeal : AppColors.champagneGold,
            onTap: hasFaceBadge ? null : onFaceVerification,
          ),
          Divider(height: 1, indent: 56, color: AppColors.cardBorder),
          _TrustRow(
            icon: Icons.alternate_email_rounded,
            title: 'Account email',
            subtitle: _maskedAccountEmail(email),
            status: emailVerified ? 'Verified' : 'Check email',
            statusColor: emailVerified
                ? AppColors.verifiedTeal
                : AppColors.champagneGold,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0x12000000),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.radiusCard),
                bottomRight: Radius.circular(AppDimensions.radiusCard),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_read_outlined,
                    color: AppColors.slateMist, size: 16),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: UiText(
                    'Official sign-in emails are sent from noreply@mail.silarah.com. Silarah will never ask for your verification code.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.slateMist, size: 21),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(title, style: AppTypography.body),
                const SizedBox(height: 2),
                UiText(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          UiText(status,
              style: AppTypography.captionMedium.copyWith(color: statusColor)),
          if (onTap != null) ...[
            const SizedBox(width: AppDimensions.space4),
            Icon(Icons.chevron_right_rounded, color: statusColor, size: 18),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return SilarahPressable(onTap: onTap, child: content);
  }
}

String _maskedAccountEmail(String? email) {
  if (email == null || !email.contains('@')) return 'Email unavailable';
  final parts = email.split('@');
  final local = parts.first;
  final visible =
      local.length <= 2 ? local.substring(0, 1) : local.substring(0, 2);
  final hiddenCount = (local.length - visible.length).clamp(2, 8);
  final hidden = List.filled(hiddenCount, '•').join();
  return '$visible$hidden@${parts.last}';
}

String _profileActionError(Object error) {
  final raw = error.toString();
  final messageMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
  final cleaned = (messageMatch?.group(1) ?? raw)
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
  return cleaned.isEmpty
      ? 'Could not complete this action. Try again.'
      : cleaned;
}

class _BoostSection extends StatefulWidget {
  @override
  State<_BoostSection> createState() => _BoostSectionState();
}

class _BoostSectionState extends State<_BoostSection> {
  DateTime? _boostedAt;
  bool _boosting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadBoostState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoostState() async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (SupabaseService.isInitialized && userId != null) {
      final row = await SupabaseService.client
          .from('my_profile_private')
          .select('is_boosted, boost_expires_at')
          .eq('user_id', userId)
          .maybeSingle();
      final expiresAt = row?['boost_expires_at'] == null
          ? null
          : DateTime.tryParse(row!['boost_expires_at'] as String)?.toLocal();
      if ((row?['is_boosted'] as bool? ?? false) &&
          expiresAt != null &&
          expiresAt.isAfter(DateTime.now())) {
        if (mounted) {
          setState(
              () => _boostedAt = expiresAt.subtract(const Duration(hours: 2)));
          _startTimer();
        }
        return;
      }

      return;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_boostedAt == null) return;
      final remaining =
          const Duration(hours: 2) - DateTime.now().difference(_boostedAt!);
      if (remaining.isNegative) {
        setState(() => _boostedAt = null);
        _timer?.cancel();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _activate() async {
    if (_boosting || _boostedAt != null) return;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!mounted) return;
    if (!SupabaseService.isInitialized || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: UiText(context
                .uiCopy('Profile boost requires a backend connection.'))),
      );
      return;
    }

    setState(() => _boosting = true);
    final now = DateTime.now();
    try {
      final response =
          await SupabaseService.client.rpc('activate_profile_boost');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        throw StateError('The boost service returned no activation state.');
      }
      final expiresAt = DateTime.tryParse(
        (rows.first as Map)['boost_expires_at']?.toString() ?? '',
      )?.toLocal();
      if (expiresAt == null || !expiresAt.isAfter(now)) {
        throw StateError('The boost activation response was incomplete.');
      }
      if (!mounted) return;
      setState(() {
        _boosting = false;
        _boostedAt = expiresAt.subtract(const Duration(hours: 2));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _boosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UiText(_profileActionError(error))),
      );
      return;
    }

    if (mounted) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.rocket_launch_rounded,
                color: AppColors.champagneGold, size: 16),
            const SizedBox(width: 8),
            UiText(context.uiCopy('Your profile is boosted for 2 hours!'),
                style: AppTypography.body.copyWith(
                  color: AppColors.readableOn(AppColors.surfaceGlassHover),
                )),
          ]),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.goldBorder),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _countdown() {
    if (_boostedAt == null) return '';
    final remaining =
        const Duration(hours: 2) - DateTime.now().difference(_boostedAt!);
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Women can use profile boosts without a paid entitlement.
    final authState = context.watch<AuthCubit>().state;
    final gender =
        authState is AuthAuthenticated ? (authState.gender ?? 'male') : 'male';
    final isFemale = gender == 'female';

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, subState) {
        final isActive = _boostedAt != null;

        // Women: always show boost as available (free, no paywall).
        // Men with no subscription: show locked state.
        final showAsSubscribed = isFemale || subState.isSubscribed;

        return AnimatedContainer(
          duration: AppDimensions.durationTransition,
          padding: const EdgeInsets.all(AppDimensions.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            gradient: showAsSubscribed
                ? LinearGradient(
                    colors: [
                      AppColors.champagneGold.withValues(alpha: 0.18),
                      AppColors.champagneGold.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: showAsSubscribed ? null : AppColors.surfaceGlass,
            border: Border.all(
              color: showAsSubscribed
                  ? AppColors.goldBorder
                  : AppColors.cardBorder,
            ),
          ),
          child: showAsSubscribed
              ? _BoostActiveOrAvailable(
                  isActive: isActive,
                  countdown: _countdown(),
                  onActivate: _activate,
                )
              : _BoostLocked(
                  onNavigate: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SubscriptionScreen()),
                  ),
                ),
        );
      },
    );
  }
}

class _BoostActiveOrAvailable extends StatelessWidget {
  const _BoostActiveOrAvailable({
    required this.isActive,
    required this.countdown,
    required this.onActivate,
  });
  final bool isActive;
  final String countdown;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.rocket_launch_rounded,
                color: AppColors.champagneGold, size: 22),
            const SizedBox(width: AppDimensions.space8),
            UiText(context.uiCopy('Boost Profile'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.champagneGold)),
            const Spacer(),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: UiText(context.uiCopy('ACTIVE'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.champagneGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    )),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        UiText(
          isActive
              ? 'Your profile is at the top of searches.'
              : 'Appear at the top of searches for 2 hours.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimensions.space12),
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightSmall,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? AppColors.surfaceGlassHover
                  : AppColors.champagneGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            onPressed: isActive ? null : onActivate,
            child: UiText(
              isActive ? countdown : 'Activate Boost',
              style: AppTypography.button.copyWith(
                color: isActive ? AppColors.slateMist : AppColors.obsidianNight,
                fontVariations: [const FontVariation('wght', 700)],
                letterSpacing: isActive ? 2 : 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoostLocked extends StatelessWidget {
  const _BoostLocked({required this.onNavigate});
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onNavigate,
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: AppColors.slateMist, size: 22),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(context.uiCopy('Profile Boost'),
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.slateMist)),
                const SizedBox(height: AppDimensions.space4),
                UiText(context.uiCopy('Subscribe to unlock profile boosts.'),
                    style: AppTypography.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.slateMist, size: AppDimensions.iconSizeMedium),
        ],
      ),
    );
  }
}

// ── Subscription Card ─────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final gender =
        authState is AuthAuthenticated ? (authState.gender ?? 'male') : 'male';
    if (gender == 'female') return const SizedBox.shrink();

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        return switch (state.status) {
          SubscriptionStatus.active => _buildActive(context, state),
          SubscriptionStatus.grace => _buildGrace(context),
          SubscriptionStatus.none => _buildUpgrade(context),
        };
      },
    );
  }

  Widget _buildActive(BuildContext context, SubscriptionState state) {
    final expiry = state.expiresAt;
    return _CardShell(
      borderColor: AppColors.verifiedTeal,
      glowColor: AppColors.verifiedTeal.withValues(alpha: 0.1),
      child: Row(children: [
        Icon(Icons.workspace_premium_rounded,
            color: AppColors.verifiedTeal, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText('SILARAH Premium · Active',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.verifiedTeal)),
            if (expiry != null)
              UiText(context.uiRenewsDate(_fmtDate(expiry)),
                  style: AppTypography.caption),
          ],
        )),
      ]),
    );
  }

  Widget _buildGrace(BuildContext context) {
    return _CardShell(
      borderColor: AppColors.premiumGold,
      glowColor: AppColors.premiumGold.withValues(alpha: 0.1),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded,
            color: AppColors.premiumGold, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: UiText(
                context.uiCopy('Payment issue — subscription in grace period.'),
                style: AppTypography.caption)),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SubscriptionScreen())),
          child: UiText(context.uiCopy('Fix'),
              style: AppTypography.captionMedium
                  .copyWith(color: AppColors.premiumGold)),
        ),
      ]),
    );
  }

  Widget _buildUpgrade(BuildContext context) {
    return SilarahPressable(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen())),
      child: _CardShell(
        borderColor: AppColors.goldBorder,
        glowColor: AppColors.goldGlow,
        child: Row(children: [
          Icon(Icons.lock_outline_rounded,
              color: AppColors.champagneGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiText('Upgrade to SILARAH Premium',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.champagneGold)),
              UiText(context.uiCopy('Unlock messaging and profile boosts'),
                  style: AppTypography.caption),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.champagneGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: UiText(context.uiCopy('Plans'),
                style: AppTypography.caption.copyWith(
                    color: AppColors.obsidianNight,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _CardShell extends StatelessWidget {
  const _CardShell(
      {required this.child,
      required this.borderColor,
      required this.glowColor});
  final Widget child;
  final Color borderColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        color: AppColors.surfaceGlass,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

// ── Badge Card (Phase 2.5) ────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.primaryPhotoUrl,
    required this.onPhotoLoadFailed,
  });

  final String? primaryPhotoUrl;
  final ValueChanged<String> onPhotoLoadFailed;

  @override
  Widget build(BuildContext context) {
    Widget child = Icon(
      Icons.person_outline_rounded,
      color: AppColors.slateMist,
      size: 36,
    );

    if (primaryPhotoUrl != null && primaryPhotoUrl!.isNotEmpty) {
      child = SilarahBlurImage(
        imageUrl: primaryPhotoUrl!,
        key: ValueKey(primaryPhotoUrl),
        fit: BoxFit.cover,
        width: 72,
        height: 72,
        onImageError: () => onPhotoLoadFailed(primaryPhotoUrl!),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceGlassHover,
        border: Border.all(color: AppColors.goldBorder, width: 2),
      ),
      child: ClipOval(child: child),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({
    required this.score,
    required this.nudge,
    required this.data,
    required this.guardianEnabled,
    required this.hasVerificationBadge,
    required this.verificationLoading,
    required this.onVerify,
    required this.primaryPhotoUrl,
    required this.onPhotoLoadFailed,
  });
  final int score;
  final String? nudge;
  final OnboardingData data;
  final bool guardianEnabled;
  final bool hasVerificationBadge;
  final bool verificationLoading;
  final VoidCallback onVerify;
  final String? primaryPhotoUrl;
  final ValueChanged<String> onPhotoLoadFailed;

  @override
  Widget build(BuildContext context) {
    final pct = score / 100.0;
    // Derive display name from real OnboardingData fields
    final displayName = [data.firstName, data.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    // Compute age from dateOfBirth
    final dob = data.dateOfBirth;
    int? age;
    if (dob != null) {
      final now = DateTime.now();
      age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
    }
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.verifiedTeal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              UiText(context.uiCopy('Profile quality'),
                  style: AppTypography.captionMedium
                      .copyWith(color: AppColors.pearlWhite)),
              const Spacer(),
              UiText('$score%',
                  style: AppTypography.captionMedium
                      .copyWith(color: AppColors.champagneGold)),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          Row(
            children: [
              _ProfileAvatar(
                primaryPhotoUrl: primaryPhotoUrl,
                onPhotoLoadFailed: onPhotoLoadFailed,
              ),
              const SizedBox(width: AppDimensions.space16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: UiText(
                        displayName.isEmpty ? 'Your Name' : displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.userName.copyWith(fontSize: 20),
                      ),
                    ),
                    if (guardianEnabled) ...[
                      const SizedBox(width: AppDimensions.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.champagneGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: UiText(context.uiCopy('Guardian Mode'),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.champagneGold,
                              fontSize: 10,
                            )),
                      ),
                    ],
                  ]),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(_buildSubtitle(context, age),
                      style: AppTypography.caption),
                  if (!verificationLoading) ...[
                    const SizedBox(height: AppDimensions.space10),
                    _VerificationIdentityStatus(
                      isVerified: hasVerificationBadge,
                      onVerify: onVerify,
                    ),
                  ],
                ],
              )),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          LayoutBuilder(builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  UiText(context.uiProfileCompleteness(score),
                      style: AppTypography.captionMedium
                          .copyWith(color: AppColors.champagneGold)),
                  const Spacer(),
                  UiText(score >= 80 ? '✓ Great profile!' : 'Keep going!',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.champagneGold)),
                ]),
                const SizedBox(height: AppDimensions.space8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: AppDimensions.durationReveal,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: AppColors.progressBarBase,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.champagneGold,
                      ),
                    ),
                  ),
                ),
                if (nudge != null) ...[
                  const SizedBox(height: AppDimensions.space8),
                  Row(children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.champagneGold, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                        child: UiText(nudge!,
                            style: AppTypography.caption.copyWith(
                                color: AppColors.champagneGold, fontSize: 11))),
                  ]),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  String _buildSubtitle(BuildContext context, int? age) {
    final parts = <String>[];
    if (age != null) parts.add(context.uiAgeYears(age));
    if (data.cityName?.isNotEmpty == true) parts.add(data.cityName!);
    return parts.isEmpty ? 'Complete your profile below' : parts.join(' · ');
  }
}

// ── Saved Profiles ────────────────────────────────────────────

class _VerificationIdentityStatus extends StatelessWidget {
  const _VerificationIdentityStatus({
    required this.isVerified,
    required this.onVerify,
  });

  final bool isVerified;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return Semantics(
        label: 'Profile photo verified',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded,
                color: AppColors.verifiedTeal, size: 16),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Photo verified'),
              style: AppTypography.captionMedium.copyWith(
                color: AppColors.verifiedTeal,
              ),
            ),
          ],
        ),
      );
    }

    return SilarahPressable(
      onTap: onVerify,
      child: Semantics(
        button: true,
        label: 'Verify profile photo with a passive face scan',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space10,
            vertical: AppDimensions.space8,
          ),
          decoration: BoxDecoration(
            color: AppColors.champagneGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined,
                  color: AppColors.champagneGold, size: 16),
              const SizedBox(width: AppDimensions.space8),
              UiText(
                context.uiCopy('Verify photo'),
                style: AppTypography.captionMedium.copyWith(
                  color: AppColors.champagneGold,
                ),
              ),
              const SizedBox(width: AppDimensions.space4),
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.champagneGold, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedProfilesSection extends StatelessWidget {
  const _SavedProfilesSection({
    required this.savedProfiles,
    required this.onChanged,
  });
  final List<DiscoveryProfile> savedProfiles;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(context.uiCopy('SAVED PROFILES'),
            style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space12),
        if (savedProfiles.isEmpty)
          const SilarahEmptyState(
            visual: SilarahEmptyVisual.savedProfiles,
            title: 'No saved profiles yet',
            subtitle: 'Tap the bookmark icon on any\nprofile to save it here.',
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: savedProfiles.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.space12),
              itemBuilder: (context, i) {
                final p = savedProfiles[i];
                return SilarahPressable(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileDetailScreen(
                          profile: p,
                          heroTag: 'saved-profile-${p.id}',
                        ),
                      ),
                    );
                    onChanged();
                  },
                  child: Container(
                    width: 90,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar circle — 52 px
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceGlassHover,
                            border: Border.all(
                                color: AppColors.goldBorder, width: 1.5),
                          ),
                          child: ClipOval(
                            child: p.photoUrl == null
                                ? Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.slateMist,
                                    size: 24,
                                  )
                                : SilarahBlurImage(
                                    imageUrl: p.photoUrl!,
                                    blurhash: p.blurhash,
                                    width: 52,
                                    height: 52,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Name
                        UiText(
                          p.firstName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.pearlWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        // City
                        UiText(
                          p.cityName,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Found a match ─────────────────────────────────────────────

class _IFoundMyMatchButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: () => _showConfirmation(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          gradient: LinearGradient(
            colors: [
              AppColors.champagneGold.withValues(alpha: 0.12),
              AppColors.champagneGold.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.space8),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    context.uiCopy('I Found My Match'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  UiText(
                    context.uiCopy('Pause your profile and sign out.'),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium),
          ],
        ),
      ),
    );
  }

  void _showConfirmation(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppDimensions.space16),
        padding: const EdgeInsets.all(AppDimensions.space24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: AppDimensions.space24),
            Icon(Icons.favorite_rounded,
                color: AppColors.champagneGold, size: 48),
            const SizedBox(height: AppDimensions.space16),
            UiText(
              context.uiCopy('Alhamdulillah!'),
              style: AppTypography.screenTitle.copyWith(
                color: AppColors.champagneGold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            UiText(
              context.uiCopy(
                  'May Allah bless your union with\nlove, mercy, and barakah.'),
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space6),
            UiText(
              context.uiCopy(
                  'Your profile will be hidden from searches.\nYou can reactivate anytime.'),
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
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
                  elevation: 0,
                ),
                onPressed: () async {
                  try {
                    await SupabaseService.client.rpc(
                      'set_profile_pause',
                      params: {'p_paused': true},
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await context.read<AuthCubit>().signOut();
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: UiText(_profileActionError(error))),
                      );
                  }
                },
                child: UiText(context.uiCopy('Confirm & Pause Profile'),
                    style: AppTypography.button),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: UiText(context.uiCopy('Cancel'),
                    style: AppTypography.button
                        .copyWith(color: AppColors.slateMist)),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
          ],
        ),
      ),
    );
  }
}
