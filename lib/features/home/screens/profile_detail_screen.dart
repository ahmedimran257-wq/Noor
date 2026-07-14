// lib/features/home/screens/profile_detail_screen.dart
// ============================================================
// SILARAH — Profile Detail Screen (Step 5 — Blueprint Complete)
//
// Blueprint requirements (Part 8):
//   • Full-screen hero photo: 55% of screen height
//   • Stretch + parallax via SliverAppBar stretchModes
//   • Multiple photos swipeable horizontally with dot indicators
//   • Tapping photo → full-screen viewer
//   • Back (top-left) + Share (top-right) + three-dot menu
//   • Three-dot → Report / Block (bottom sheet)
//   • Bio in italic Playfair Display ("their own words")
//   • Interests as outlined GOLD chips
//   • Compatibility indicator: "You match N of their M preferences"
//   • Sticky bottom bar: bookmark + gold "Send Interest"
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/loaders/silarah_blur_image.dart';
import '../../../core/models/discovery_profile.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/services/compatibility_service.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/interest_ceremony_overlay.dart';
import '../widgets/interest_note_sheet.dart';
import '../widgets/report_bottom_sheet.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
    required this.heroTag,
    required this.isInterestSent,
    required this.onInterestSent,
    this.isMutualMatch = false,
    this.isOwnProfile = false,
  });

  final DiscoveryProfile profile;
  final String heroTag;
  final bool isInterestSent;
  final VoidCallback onInterestSent;
  final bool isMutualMatch;
  final bool isOwnProfile;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late bool _interestSent;
  bool _bookmarked = false;
  int _photoPage = 0;
  late final PageController _photoController;
  late List<String?> _photoUrls;
  bool _isGalleryLoading = false;
  bool _galleryLoadFailed = false;
  final Set<int> _refreshingPhotoIndexes = <int>{};
  final Set<int> _refreshedPhotoIndexes = <int>{};

  int get _totalPhotos => _photoUrls.length;

  @override
  void initState() {
    super.initState();
    _interestSent = widget.isInterestSent;
    _photoController = PageController();
    _photoUrls = _initialPhotoUrls(widget.profile);
    if (_photoUrls.whereType<String>().length < _photoUrls.length) {
      _loadAuthorizedGallery();
    }
    // Load persisted bookmark state
    BookmarkService.load().then((ids) {
      if (mounted) {
        setState(() => _bookmarked = ids.contains(widget.profile.id));
      }
    }).catchError((_) {});
  }

  List<String?> _initialPhotoUrls(DiscoveryProfile profile) {
    final urls = profile.orderedPhotoUrls;
    final total = math.max(profile.photoCount, urls.length).clamp(1, 4);
    return List<String?>.generate(
      total,
      (index) => index < urls.length ? urls[index] : null,
      growable: false,
    );
  }

  Future<void> _loadAuthorizedGallery() async {
    if (_isGalleryLoading) return;
    setState(() {
      _isGalleryLoading = true;
      _galleryLoadFailed = false;
    });
    try {
      final slots = await ProfilePhotoService.instance.getVisiblePhotoSlots(
        ownerUserId: widget.profile.id,
      );
      final entries = slots.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final urls = entries.map((entry) => entry.value).toList(growable: false);
      if (!mounted) return;
      final total =
          math.max(widget.profile.photoCount, urls.length).clamp(1, 4);
      setState(() {
        _photoUrls = List<String?>.generate(
          total,
          (index) => index < urls.length ? urls[index] : null,
          growable: false,
        );
        _isGalleryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGalleryLoading = false;
        _galleryLoadFailed = true;
      });
    }
  }

  Future<void> _refreshExpiredPhoto(int index) async {
    if (index < 0 ||
        index >= _photoUrls.length ||
        _refreshingPhotoIndexes.contains(index) ||
        _refreshedPhotoIndexes.contains(index)) {
      return;
    }
    _refreshingPhotoIndexes.add(index);
    _refreshedPhotoIndexes.add(index);
    try {
      final refreshed =
          await ProfilePhotoService.instance.getAuthorizedPhotoUrl(
        ownerUserId: widget.profile.id,
        orderIndex: index,
        forceRefresh: true,
      );
      if (!mounted || refreshed == null || refreshed.isEmpty) return;
      setState(() => _photoUrls[index] = refreshed);
    } finally {
      _refreshingPhotoIndexes.remove(index);
    }
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _handleSendInterest() async {
    // D1: Show note sheet before sending
    final note = await showInterestNoteSheet(
      context,
      firstName: widget.profile.firstName,
    );
    // null = user cancelled
    if (note == null || !mounted) return;

    // M6: Sync interest to cubit so feed state stays consistent
    final sent = await context.read<InterestsCubit>().sendInterest(
          widget.profile,
          note: note.isNotEmpty ? note : null,
        );
    if (!mounted || !sent) return;
    setState(() => _interestSent = true);
    widget.onInterestSent();
    HapticFeedback.mediumImpact();
    await showInterestCeremony(context, firstName: widget.profile.firstName);
  }

  Future<void> _handleBookmark() async {
    HapticFeedback.selectionClick();
    final previous = _bookmarked;
    setState(() => _bookmarked = !_bookmarked);

    try {
      final ids =
          await BookmarkService.setSaved(widget.profile.id, _bookmarked);
      if (mounted) {
        setState(() => _bookmarked = ids.contains(widget.profile.id));
      }
    } catch (_) {
      if (mounted) setState(() => _bookmarked = previous);
    }
  }

  void _handleShare() {
    HapticFeedback.selectionClick();
    // TD4: Copy a share link to clipboard
    final shareText = 'Check out ${widget.profile.firstName} on SILARAH — '
        'silarah.com/profile/${widget.profile.id}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile link copied to clipboard'),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
    );
  }

  void _showMoreMenu() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BlockReportCubit>(),
        child: _ReportBlockSheet(
          profile: widget.profile,
          onBlock: () {
            context.read<BlockReportCubit>().blockUser(
                  userId: widget.profile.id,
                  name: widget.profile.firstName,
                  lastInitial: widget.profile.lastNameInitial,
                );
          },
          onReport: () => ReportBottomSheet.show(
            context,
            reportedUserId: widget.profile.id,
            reportedName: widget.profile.firstName,
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────
          CustomScrollView(
            slivers: [
              // ── Photo hero with parallax + carousel ──────────
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.55,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.obsidianNight,
                leading: _HeaderButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                actions: [
                  _HeaderButton(
                    icon: Icons.ios_share_rounded,
                    onTap: _handleShare,
                  ),
                  if (!widget.isOwnProfile) ...[
                    const SizedBox(width: AppDimensions.space4),
                    _HeaderButton(
                      icon: Icons.more_vert_rounded,
                      onTap: _showMoreMenu,
                    ),
                  ],
                  const SizedBox(width: AppDimensions.space8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Hero(
                    tag: widget.heroTag,
                    child: _PhotoCarousel(
                      profile: p,
                      controller: _photoController,
                      photoUrls: _photoUrls,
                      totalPhotos: _totalPhotos,
                      currentPage: _photoPage,
                      onPageChanged: (i) => setState(() => _photoPage = i),
                      isMutualMatch: widget.isMutualMatch,
                      isLoading: _isGalleryLoading,
                      loadFailed: _galleryLoadFailed,
                      onRetry: _loadAuthorizedGallery,
                      onPhotoLoadError: _refreshExpiredPhoto,
                    ),
                  ),
                ),
              ),

              // ── Profile content ───────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space24,
                  AppDimensions.space24,
                  AppDimensions.space24,
                  120, // room for the sticky CTA bar
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Name + age + location
                    _NameBlock(profile: p, isMutualMatch: widget.isMutualMatch),
                    const SizedBox(height: AppDimensions.space20),

                    // Compatibility indicator
                    if (widget.isOwnProfile)
                      const _OwnProfilePreviewNotice()
                    else
                      _CompatibilityIndicator(profile: p),
                    const SizedBox(height: AppDimensions.space28),

                    // About — bio in italic Playfair Display
                    if (p.bio != null) ...[
                      const _SectionHeader(label: 'About'),
                      const SizedBox(height: AppDimensions.space12),
                      Text(p.bio!, style: AppTypography.bio),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Islamic Background
                    if (p.sect != null ||
                        p.deenLevel != null ||
                        p.motherTongue != null ||
                        p.smokingHabit != null ||
                        p.quranMemorization != null ||
                        p.religiousEducation != null) ...[
                      const _SectionHeader(label: 'Islamic Life'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.sect != null)
                          _DetailItem(label: 'Sect', value: p.sect!),
                        if (p.deenLevel != null)
                          _DetailItem(
                              label: 'Deen Level',
                              value: _formatDeen(p.deenLevel!)),
                        if (p.motherTongue != null)
                          _DetailItem(
                              label: 'Mother Tongue', value: p.motherTongue!),
                        if (p.quranMemorization != null)
                          _DetailItem(
                              label: 'Quran',
                              value: _formatQuran(p.quranMemorization!)),
                        if (p.religiousEducation != null)
                          _DetailItem(
                              label: 'Religious Education',
                              value:
                                  _formatReligiousEdu(p.religiousEducation!)),
                        if (p.smokingHabit != null)
                          _DetailItem(label: 'Smoking', value: p.smokingHabit!),
                        if (p.vapingHabit != null)
                          _DetailItem(label: 'Vaping', value: p.vapingHabit!),
                        if (p.hookahHabit != null)
                          _DetailItem(label: 'Hookah', value: p.hookahHabit!),
                      ]),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Background
                    // Education & Career (no marital/family — those go in Family)
                    if (p.occupation != null ||
                        p.education != null ||
                        p.incomeBracket != null) ...[
                      const _SectionHeader(label: 'Education & Career'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.occupation != null)
                          _DetailItem(
                              label: 'Occupation', value: p.occupation!),
                        if (p.education != null)
                          _DetailItem(label: 'Education', value: p.education!),
                        if (p.incomeBracket != null)
                          _DetailItem(
                            label: 'Income Bracket',
                            value: widget.isMutualMatch
                                ? p.incomeBracket!
                                : '🔒 Locked (Mutual match only)',
                          ),
                      ]),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Family — blueprint section 5 of 6
                    if (p.familyType != null ||
                        p.maritalStatus != null ||
                        p.marriageTimeline != null ||
                        p.willingToRelocate != null ||
                        p.familyOriginCity != null) ...[
                      const _SectionHeader(label: 'Family & Future'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.familyType != null)
                          _DetailItem(
                              label: 'Family Type', value: p.familyType!),
                        if (p.maritalStatus != null)
                          _DetailItem(
                              label: 'Marital Status', value: p.maritalStatus!),
                        if (p.marriageTimeline != null)
                          _DetailItem(
                              label: 'Timeline',
                              value: _formatTimeline(p.marriageTimeline!)),
                        if (p.willingToRelocate != null)
                          _DetailItem(
                              label: 'Relocate',
                              value: _formatRelocate(p.willingToRelocate!)),
                        if (p.livingExpectation != null)
                          _DetailItem(
                              label: 'Living',
                              value: _formatLiving(p.livingExpectation!)),
                        if (p.familyOriginCity != null)
                          _DetailItem(
                            label: 'Origin City',
                            value: widget.isMutualMatch
                                ? p.familyOriginCity!
                                : '🔒 Locked (Mutual match only)',
                          ),
                      ]),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Interests — gold outlined chips (blueprint: after Family)
                    if (p.interests != null && p.interests!.isNotEmpty) ...[
                      const _SectionHeader(label: 'Interests'),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: p.interests!
                            .map((i) => _GoldChip(label: i))
                            .toList(),
                      ),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Languages
                    if (p.languages != null && p.languages!.isNotEmpty) ...[
                      const _SectionHeader(label: 'Languages'),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: p.languages!
                            .map((l) => _DetailChip(label: l))
                            .toList(),
                      ),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Looking For — blueprint section 6 of 6
                    if (p.partnerAgeMin != null || p.partnerAgeMax != null) ...[
                      const _SectionHeader(label: 'Looking For'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        if (p.partnerAgeMin != null && p.partnerAgeMax != null)
                          _DetailItem(
                            label: 'Age Range',
                            value: '${p.partnerAgeMin} – ${p.partnerAgeMax}',
                          ),
                        if (p.sect != null)
                          _DetailItem(
                              label: 'Sect Preference',
                              value: 'Same (${p.sect})'),
                      ]),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // ── Sticky bottom bar ─────────────────────────────────
          if (!widget.isOwnProfile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CtaBar(
                firstName: p.firstName,
                isInterestSent: _interestSent,
                isBookmarked: _bookmarked,
                onSendInterest: _interestSent ? null : _handleSendInterest,
                onBookmark: _handleBookmark,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDeen(String raw) {
    switch (raw) {
      case 'practicing':
        return 'Practicing';
      case 'moderate':
        return 'Moderate';
      case 'cultural':
        return 'Cultural';
      default:
        return raw;
    }
  }

  String _formatQuran(String raw) {
    switch (raw) {
      case 'none':
        return 'None';
      case 'some_surahs':
        return 'Some Surahs';
      case 'partial':
        return 'Partial';
      case 'hafiz':
        return 'Hafiz';
      default:
        return raw;
    }
  }

  String _formatReligiousEdu(String raw) {
    switch (raw) {
      case 'self_taught':
        return 'Self-taught';
      case 'madrasa':
        return 'Madrasa';
      case 'islamic_uni':
        return 'Islamic University';
      case 'alim_course':
        return 'Alim Course';
      case 'none':
        return 'None';
      default:
        return raw;
    }
  }

  String _formatTimeline(String raw) {
    switch (raw) {
      case 'asap':
        return 'ASAP';
      case '6_months':
        return '6 Months';
      case '1_year':
        return '1 Year';
      case '2_plus_years':
        return '2+ Years';
      case 'not_sure':
        return 'Not Sure';
      default:
        return raw;
    }
  }

  String _formatRelocate(String raw) {
    switch (raw) {
      case 'yes':
        return 'Yes';
      case 'no':
        return 'No';
      case 'open_to_discussion':
        return 'Open';
      default:
        return raw;
    }
  }

  String _formatLiving(String raw) {
    switch (raw) {
      case 'with_inlaws':
        return 'With In-Laws';
      case 'separate':
        return 'Separate';
      case 'open_to_discussion':
        return 'Flexible';
      default:
        return raw;
    }
  }
}

// ── Photo Carousel ────────────────────────────────────────────

class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.profile,
    required this.controller,
    required this.photoUrls,
    required this.totalPhotos,
    required this.currentPage,
    required this.onPageChanged,
    required this.isMutualMatch,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onPhotoLoadError,
  });

  final DiscoveryProfile profile;
  final PageController controller;
  final List<String?> photoUrls;
  final int totalPhotos;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final bool isMutualMatch;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final ValueChanged<int> onPhotoLoadError;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Page-swipeable photo area
        PageView.builder(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          itemCount: totalPhotos,
          onPageChanged: onPageChanged,
          itemBuilder: (_, i) => _SinglePhotoSlide(
            profile: profile,
            index: i,
            photoUrl: i < photoUrls.length ? photoUrls[i] : null,
            photoUrls: photoUrls,
            isMutualMatch: isMutualMatch,
            isLoading: isLoading,
            loadFailed: loadFailed,
            onRetry: onRetry,
            onPhotoLoadError: onPhotoLoadError,
          ),
        ),

        // Bottom gradient fade
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.obsidianNight],
                stops: [0.5, 1.0],
              ),
            ),
          ),
        ),

        if (totalPhotos > 1) ...[
          Positioned(
            right: AppDimensions.space16,
            top: MediaQuery.of(context).padding.top + 64,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space10,
                  vertical: AppDimensions.space6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlayBlack55,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPhotos',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.pearlWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (currentPage > 0)
            Positioned(
              left: AppDimensions.space12,
              top: 0,
              bottom: 0,
              child: _GalleryNavButton(
                icon: Icons.chevron_left_rounded,
                semanticLabel: 'Previous photo',
                onTap: () => controller.previousPage(
                  duration: AppDimensions.durationTransition,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          if (currentPage < totalPhotos - 1)
            Positioned(
              right: AppDimensions.space12,
              top: 0,
              bottom: 0,
              child: _GalleryNavButton(
                icon: Icons.chevron_right_rounded,
                semanticLabel: 'Next photo',
                onTap: () => controller.nextPage(
                  duration: AppDimensions.durationTransition,
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
        ],

        // Photo dot indicators — bottom center
        if (totalPhotos > 1)
          Positioned(
            bottom: AppDimensions.space20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < totalPhotos; i++)
                  AnimatedContainer(
                    duration: AppDimensions.durationTransition,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == currentPage ? 16 : 6,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == currentPage
                          ? AppColors.champagneGold
                          : AppColors.pearlWhite.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SinglePhotoSlide extends StatelessWidget {
  const _SinglePhotoSlide({
    required this.profile,
    required this.index,
    required this.photoUrl,
    required this.photoUrls,
    required this.isMutualMatch,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onPhotoLoadError,
  });
  final DiscoveryProfile profile;
  final int index;
  final String? photoUrl;
  final List<String?> photoUrls;
  final bool isMutualMatch;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final ValueChanged<int> onPhotoLoadError;

  @override
  Widget build(BuildContext context) {
    final isPrivate = profile.isPhotoPrivate && index > 0 && !isMutualMatch;

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2F), AppColors.obsidianNight],
          ),
        ),
        child: isPrivate
            ? _PrivateSlide(photoCount: profile.photoCount)
            : _PublicSlide(
                photoUrl: photoUrl,
                blurhash: index == 0 ? profile.blurhash : null,
                isLoading: isLoading,
                loadFailed: loadFailed,
                onRetry: onRetry,
                onImageError: () => onPhotoLoadError(index),
              ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    // Full-screen viewer — tapping a photo zooms it
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: AppColors.overlayBlack87,
        barrierDismissible: true,
        pageBuilder: (ctx, animation, _) => FadeTransition(
          opacity: animation,
          child: _FullScreenPhotoViewer(
            profile: profile,
            initialIndex: index,
            photoUrls: photoUrls,
            isMutualMatch: isMutualMatch,
          ),
        ),
      ),
    );
  }
}

class _PublicSlide extends StatelessWidget {
  const _PublicSlide({
    required this.photoUrl,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    required this.onImageError,
    this.blurhash,
  });
  final String? photoUrl;
  final String? blurhash;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback onRetry;
  final VoidCallback onImageError;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return SilarahBlurImage(
        imageUrl: photoUrl!,
        blurhash: blurhash,
        fit: BoxFit.cover,
        onImageError: onImageError,
      );
    }
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.champagneGold,
          strokeWidth: 2,
        ),
      );
    }
    if (loadFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reload photo'),
        ),
      );
    }
    return const _PersonPlaceholder();
  }
}

class _GalleryNavButton extends StatelessWidget {
  const _GalleryNavButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.overlayBlack55,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(icon, color: AppColors.pearlWhite, size: 28),
          ),
        ),
      ),
    );
  }
}

class _PrivateSlide extends StatelessWidget {
  const _PrivateSlide({required this.photoCount});
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder, width: 2),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.slateMist,
              size: 40,
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          Text(
            '$photoCount photo${photoCount != 1 ? 's' : ''}\nvisible after acceptance',
            style: AppTypography.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PersonPlaceholder extends StatelessWidget {
  const _PersonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.person_outline_rounded,
          color: AppColors.slateMist, size: 80),
    );
  }
}

// ── Full-Screen Photo Viewer ──────────────────────────────────

class _FullScreenPhotoViewer extends StatefulWidget {
  const _FullScreenPhotoViewer({
    required this.profile,
    required this.initialIndex,
    required this.photoUrls,
    required this.isMutualMatch,
  });
  final DiscoveryProfile profile;
  final int initialIndex;
  final List<String?> photoUrls;
  final bool isMutualMatch;

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPhotos = widget.photoUrls.length;

    return Stack(
      children: [
        // Dismissible background
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.transparent),
        ),
        PageView.builder(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          itemCount: totalPhotos,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (_, index) {
            final isPrivate = widget.profile.isPhotoPrivate &&
                index > 0 &&
                !widget.isMutualMatch;
            final photoUrl = widget.photoUrls[index];
            return Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1A1A2F), AppColors.obsidianNight],
                    ),
                  ),
                  child: isPrivate
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  color: AppColors.slateMist, size: 60),
                              SizedBox(height: 12),
                              Text('Locked', style: AppTypography.bodyMuted),
                            ],
                          ),
                        )
                      : photoUrl != null
                          ? SilarahBlurImage(
                              imageUrl: photoUrl,
                              blurhash:
                                  index == 0 ? widget.profile.blurhash : null,
                              fit: BoxFit.contain,
                            )
                          : const _PersonPlaceholder(),
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.pearlWhite, size: 20),
              ),
            ),
          ),
        ),
        if (totalPhotos > 1)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: AppDimensions.space20),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical: AppDimensions.space6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlayBlack55,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  '${_page + 1} / $totalPhotos',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.pearlWhite,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Header Icon Button ────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.space4),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon,
            color: AppColors.pearlWhite, size: AppDimensions.iconSizeMedium),
      ),
    );
  }
}

// ── Name Block ────────────────────────────────────────────────

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.profile, required this.isMutualMatch});
  final DiscoveryProfile profile;
  final bool isMutualMatch;

  @override
  Widget build(BuildContext context) {
    // Height display helper
    String? heightStr;
    if (profile.heightCm != null) {
      final cm = profile.heightCm!;
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = totalInches.round() % 12;
      heightStr = '$cm cm ($feet ft $inches in)';
    }

    final displayName = isMutualMatch
        ? '${profile.firstName} ${profile.lastName ?? profile.lastNameInitial}'
        : '${profile.firstName} ${profile.lastNameInitial}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: AppTypography.screenTitle.copyWith(fontSize: 30),
              ),
            ),
            if (profile.isVerified) _VerifiedPill(),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          [
            '${profile.age}',
            profile.cityName,
            if (heightStr != null) heightStr,
          ].join(' · '),
          style: AppTypography.body.copyWith(color: AppColors.slateMist),
        ),
      ],
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.verifiedTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: AppColors.verifiedTeal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded,
              color: AppColors.verifiedTeal, size: 12),
          const SizedBox(width: AppDimensions.space4),
          Text(
            'Verified',
            style: AppTypography.caption.copyWith(
              color: AppColors.verifiedTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compatibility Indicator ───────────────────────────────────
// Blueprint: "A compatibility indicator shows how many of the profile
// owner's stated preferences match the viewer's profile —
// 'You match 4 of their 5 preferences.'"
//
// TD7: Now uses the viewer's own OnboardingData for real comparison.

class _OwnProfilePreviewNotice extends StatelessWidget {
  const _OwnProfilePreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space14),
      decoration: BoxDecoration(
        color: AppColors.inkTeal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:
            Border.all(color: AppColors.verifiedTeal.withValues(alpha: 0.38)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined,
              color: AppColors.verifiedTeal, size: 20),
          SizedBox(width: AppDimensions.space10),
          Expanded(
            child: Text(
              'Preview mode — this is how your profile appears in discovery.',
              style: AppTypography.captionMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityIndicator extends StatelessWidget {
  const _CompatibilityIndicator({required this.profile});
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    final myData = context.read<OnboardingCubit>().currentData;
    final compatibility = calculateCompatibility(
      viewer: myData,
      candidate: profile,
    );
    final totalPrefs = compatibility.total;
    final matched = compatibility.matched;

    if (totalPrefs == 0) return const SizedBox.shrink();

    final fraction = compatibility.fraction;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          // Progress arc ring
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: fraction,
                  backgroundColor: AppColors.surfaceGlassHover,
                  color: AppColors.champagneGold,
                  strokeWidth: 3,
                ),
                Text(
                  '${(fraction * 100).round()}%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You match $matched of their $totalPrefs preferences',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.champagneGold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppDimensions.space4),
                const Text(
                  'Based on sect, deen, education & age preferences',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }
}

// ── Detail Grid ───────────────────────────────────────────────

class _DetailItem {
  const _DetailItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space12,
      runSpacing: AppDimensions.space12,
      children: items.map((item) => _DetailTile(item: item)).toList(),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.item});
  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space4),
          Text(item.value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

// ── Gold Chip (Interests — blueprint-specified gold outline) ──

class _GoldChip extends StatelessWidget {
  const _GoldChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border:
            Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTypography.chipLabel.copyWith(color: AppColors.champagneGold),
      ),
    );
  }
}

// ── Plain Chip (Languages etc.) ───────────────────────────────

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(label, style: AppTypography.chipLabel),
    );
  }
}

// ── CTA Bar (sticky bottom) ───────────────────────────────────

class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.firstName,
    required this.isInterestSent,
    required this.isBookmarked,
    this.onSendInterest,
    required this.onBookmark,
  });

  final String firstName;
  final bool isInterestSent;
  final bool isBookmarked;
  final Future<void> Function()? onSendInterest;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space12,
        AppDimensions.space24,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.obsidianNight],
        ),
      ),
      child: Row(
        children: [
          // Bookmark button — left
          GestureDetector(
            onTap: onBookmark,
            child: AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width: AppDimensions.buttonHeight,
              height: AppDimensions.buttonHeight,
              decoration: BoxDecoration(
                color: isBookmarked
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(
                  color: isBookmarked
                      ? AppColors.champagneGold
                      : AppColors.cardBorder,
                ),
              ),
              child: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: isBookmarked
                    ? AppColors.champagneGold
                    : AppColors.pearlWhite,
                size: AppDimensions.iconSizeLarge,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Send Interest — fills remaining space
          Expanded(
            child: GestureDetector(
              onTap: isInterestSent ? null : () => onSendInterest?.call(),
              child: AnimatedContainer(
                duration: AppDimensions.durationTransition,
                height: AppDimensions.buttonHeight,
                decoration: BoxDecoration(
                  color: isInterestSent
                      ? AppColors.champagneGold.withValues(alpha: 0.15)
                      : AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: isInterestSent
                      ? Border.all(color: AppColors.champagneGold)
                      : null,
                ),
                child: Center(
                  child: Text(
                    isInterestSent
                        ? 'Interest Sent ✓'
                        : 'Send Interest to $firstName',
                    style: isInterestSent
                        ? AppTypography.button
                            .copyWith(color: AppColors.champagneGold)
                        : AppTypography.button,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report / Block Bottom Sheet ───────────────────────────────
// Upgraded to use BlockReportCubit + ReportBottomSheet (Step 10)

class _ReportBlockSheet extends StatelessWidget {
  const _ReportBlockSheet({
    required this.profile,
    required this.onBlock,
    required this.onReport,
  });

  final DiscoveryProfile profile;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          _SheetAction(
            icon: Icons.flag_outlined,
            label: 'Report ${profile.firstName}',
            color: AppColors.softCoral,
            onTap: () {
              Navigator.pop(context);
              // Small delay so first sheet fully closes before second opens
              Future.microtask(onReport);
            },
          ),
          const SizedBox(height: AppDimensions.space4),
          const Divider(color: AppColors.divider),
          const SizedBox(height: AppDimensions.space4),
          _SheetAction(
            icon: Icons.block_rounded,
            label: 'Block ${profile.firstName}',
            color: AppColors.softCoral,
            onTap: () {
              Navigator.pop(context);
              onBlock();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${profile.firstName} blocked.',
                    style: AppTypography.body,
                  ),
                  backgroundColor: AppColors.surfaceGlassHover,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(height: AppDimensions.space12),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: AppTypography.button
                      .copyWith(color: AppColors.slateMist)),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space14,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: AppDimensions.iconSizeLarge),
            const SizedBox(width: AppDimensions.space12),
            Text(label, style: AppTypography.bodyMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
