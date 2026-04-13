// lib/features/home/screens/profile_detail_screen.dart
// ============================================================
// NOOR — Profile Detail Screen
// Full read-only profile opened on card tap.
// Sections: Photo hero, Identity, About, Islamic Background,
//           Family Background, Partner Preferences.
// Bottom CTA: Send Interest / Interest Already Sent
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/interest_ceremony_overlay.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profile,
    required this.heroTag,
    required this.isInterestSent,
    required this.onInterestSent,
  });

  final MockProfile  profile;
  final String       heroTag;
  final bool         isInterestSent;
  final VoidCallback onInterestSent;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late bool _interestSent;

  @override
  void initState() {
    super.initState();
    _interestSent = widget.isInterestSent;
  }

  Future<void> _handleSendInterest() async {
    setState(() => _interestSent = true);
    widget.onInterestSent();
    await showInterestCeremony(context, firstName: widget.profile.firstName);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: Stack(
        children: [
          // ── Scrollable content ────────────────────────────
          CustomScrollView(
            slivers: [
              // Photo + name hero
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.55,
                pinned:         true,
                backgroundColor: AppColors.obsidianNight,
                leading: IconButton(
                  icon:    const Icon(Icons.arrow_back_rounded, color: AppColors.pearlWhite),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: widget.heroTag,
                    child: _PhotoHero(profile: p),
                  ),
                ),
              ),

              // Profile content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space24,
                  AppDimensions.space24,
                  AppDimensions.space24,
                  120, // bottom padding for the CTA bar
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Name + age + location
                    _NameBlock(profile: p),
                    const SizedBox(height: AppDimensions.space28),

                    // About section
                    if (p.bio != null) ...[
                      _SectionHeader(label: 'About'),
                      const SizedBox(height: AppDimensions.space12),
                      Text(p.bio!, style: AppTypography.bio),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Islamic Background
                    _SectionHeader(label: 'Islamic Background'),
                    const SizedBox(height: AppDimensions.space12),
                    _DetailGrid(items: [
                      if (p.sect      != null) _DetailItem(label: 'Sect',       value: p.sect!),
                      if (p.deenLevel != null) _DetailItem(label: 'Deen Level', value: _formatDeen(p.deenLevel!)),
                    ]),
                    const SizedBox(height: AppDimensions.space28),

                    // Background
                    _SectionHeader(label: 'Background'),
                    const SizedBox(height: AppDimensions.space12),
                    _DetailGrid(items: [
                      if (p.occupation != null) _DetailItem(label: 'Occupation', value: p.occupation!),
                      if (p.education  != null) _DetailItem(label: 'Education',  value: p.education!),
                      if (p.maritalStatus != null) _DetailItem(label: 'Marital Status', value: p.maritalStatus!),
                      if (p.familyType    != null) _DetailItem(label: 'Family Type',    value: p.familyType!),
                    ]),
                    const SizedBox(height: AppDimensions.space28),

                    // Interests
                    if (p.interests != null && p.interests!.isNotEmpty) ...[
                      _SectionHeader(label: 'Interests'),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing:    AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: p.interests!
                            .map((i) => _DetailChip(label: i))
                            .toList(),
                      ),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Languages
                    if (p.languages != null && p.languages!.isNotEmpty) ...[
                      _SectionHeader(label: 'Languages'),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing:    AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: p.languages!
                            .map((l) => _DetailChip(label: l))
                            .toList(),
                      ),
                      const SizedBox(height: AppDimensions.space28),
                    ],

                    // Partner Preferences
                    if (p.partnerAgeMin != null && p.partnerAgeMax != null) ...[
                      _SectionHeader(label: 'Partner Preferences'),
                      const SizedBox(height: AppDimensions.space12),
                      _DetailGrid(items: [
                        _DetailItem(
                          label: 'Age Range',
                          value: '${p.partnerAgeMin} – ${p.partnerAgeMax}',
                        ),
                      ]),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // ── Floating CTA bar ──────────────────────────────
          Positioned(
            left:   0,
            right:  0,
            bottom: 0,
            child: _CtaBar(
              firstName:      p.firstName,
              isInterestSent: _interestSent,
              onSendInterest: _interestSent ? null : _handleSendInterest,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeen(String raw) {
    switch (raw) {
      case 'practicing': return 'Practicing';
      case 'moderate':   return 'Moderate';
      case 'cultural':   return 'Cultural';
      default:           return raw;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({required this.profile});
  final MockProfile profile;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient (photos are private in mock)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A2F),
                AppColors.obsidianNight,
              ],
            ),
          ),
          child: profile.isPhotoPrivate
              ? _PrivateHeroContent(photoCount: profile.photoCount)
              : const _PublicHeroPlaceholder(),
        ),
        // Bottom gradient fade
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.obsidianNight,
              ],
              stops: [0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicHeroPlaceholder extends StatelessWidget {
  const _PublicHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.person_outline_rounded,
        color: AppColors.slateMist,
        size:  80,
      ),
    );
  }
}

class _PrivateHeroContent extends StatelessWidget {
  const _PrivateHeroContent({required this.photoCount});
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder, width: 2),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.slateMist,
              size:  48,
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

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.profile});
  final MockProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${profile.firstName} ${profile.lastNameInitial}.',
                style: AppTypography.screenTitle.copyWith(fontSize: 30),
              ),
            ),
            if (profile.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space8,
                  vertical:   AppDimensions.space4,
                ),
                decoration: BoxDecoration(
                  color:        AppColors.verifiedTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                  border: Border.all(color: AppColors.verifiedTeal),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.verifiedTeal, size: 12),
                    const SizedBox(width: AppDimensions.space4),
                    Text('Verified',
                        style: AppTypography.caption.copyWith(
                          color:      AppColors.verifiedTeal,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          '${profile.age} · ${profile.cityName}',
          style: AppTypography.body.copyWith(color: AppColors.slateMist),
        ),
      ],
    );
  }
}

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
      spacing:    AppDimensions.space16,
      runSpacing: AppDimensions.space16,
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
        vertical:   AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical:   AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Text(label, style: AppTypography.chipLabel),
    );
  }
}

class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.firstName,
    required this.isInterestSent,
    this.onSendInterest,
  });

  final String    firstName;
  final bool      isInterestSent;
  final Future<void> Function()? onSendInterest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space16,
        AppDimensions.space24,
        AppDimensions.space16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.obsidianNight],
        ),
      ),
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: isInterestSent
              ? AppColors.champagneGold.withValues(alpha: 0.15)
              : AppColors.champagneGold,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: isInterestSent
              ? Border.all(color: AppColors.champagneGold)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            onTap: onSendInterest,
            child: Center(
              child: Text(
                isInterestSent ? 'Interest Sent ✓' : 'Send Interest to $firstName',
                style: isInterestSent
                    ? AppTypography.button.copyWith(color: AppColors.champagneGold)
                    : AppTypography.button,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
