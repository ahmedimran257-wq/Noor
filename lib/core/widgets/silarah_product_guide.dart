import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'buttons/silarah_primary_button.dart';
import 'overlays/silarah_bottom_sheet.dart';

/// A concise, replayable explanation of Silarah's relationship journey.
///
/// This is deliberately optional and uses one continuous editorial surface
/// instead of a blocking carousel. The same guide is available before signup
/// and later from Help & Support.
abstract final class SilarahProductGuide {
  static Future<void> show(BuildContext context) {
    return showSilarahBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      barrierColor: AppColors.overlayBlack55,
      builder: (_) => const _ProductGuideSheet(),
    );
  }
}

class _ProductGuideSheet extends StatelessWidget {
  const _ProductGuideSheet();

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxHeight = screen.height * (screen.height < 700 ? .95 : .90);

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: Material(
          color: AppColors.surfaceElevated,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusCard),
            ),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              const SilarahSheetHandle(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.horizontalMargin,
                    AppDimensions.space8,
                    AppDimensions.horizontalMargin,
                    AppDimensions.space24,
                  ),
                  children: [
                    Semantics(
                      header: true,
                      child: UiText(
                        context.uiCopy('How Silarah works'),
                        style: AppTypography.screenTitle.copyWith(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space6),
                    UiText(
                      context.uiCopy(
                        'A clear path from discovery to a considered conversation.',
                      ),
                      style: AppTypography.bodyMuted,
                    ),
                    const SizedBox(height: AppDimensions.space24),
                    _GuideStep(
                      number: '01',
                      kind: _GuideStepKind.discovery,
                      title: context.uiCopy('Discover with intention'),
                      body: context.uiCopy(
                        'Read complete profiles, refine compatibility, and save someone when you need time to consider.',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space12),
                    _GuideStep(
                      number: '02',
                      kind: _GuideStepKind.interest,
                      title: context.uiCopy('Express interest clearly'),
                      body: context.uiCopy(
                        'Send an interest when a profile feels promising. Its status remains visible, and either person can close the path respectfully.',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space12),
                    _GuideStep(
                      number: '03',
                      kind: _GuideStepKind.conversation,
                      title: context.uiCopy('Connect after acceptance'),
                      body: context.uiCopy(
                        'A conversation opens only after an interest is accepted. Women message free; men use Premium to send messages.',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),
                    _ControlNote(
                      title: context.uiCopy('You remain in control'),
                      body: context.uiCopy(
                        'Choose who can see your photos, involve a Guardian if you wish, and use block or report controls whenever needed.',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.horizontalMargin,
                  AppDimensions.space12,
                  AppDimensions.horizontalMargin,
                  MediaQuery.paddingOf(context).bottom + AppDimensions.space12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(
                    top: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: SilarahPrimaryButton(
                  label: context.uiCopy('Done'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GuideStepKind { discovery, interest, conversation }

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.kind,
    required this.title,
    required this.body,
  });

  final String number;
  final _GuideStepKind kind;
  final String title;
  final String body;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: UiText(
              number,
              style: AppTypography.sectionLabel.copyWith(
                color: AppColors.champagneGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(title, style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  body,
                  style: AppTypography.caption.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 390 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18) ...[
            const SizedBox(width: AppDimensions.space12),
            _GuideMiniature(kind: kind),
          ],
        ],
      ),
    );
  }
}

class _ControlNote extends StatelessWidget {
  const _ControlNote({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.goldGlow,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 20,
              color: AppColors.champagneGold,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(title, style: AppTypography.bodyMedium),
                const SizedBox(height: AppDimensions.space4),
                UiText(
                  body,
                  style: AppTypography.caption.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideMiniature extends StatelessWidget {
  const _GuideMiniature({required this.kind});

  final _GuideStepKind kind;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 76,
        height: 68,
        padding: const EdgeInsets.all(AppDimensions.space8),
        decoration: BoxDecoration(
          color: AppColors.inputSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: switch (kind) {
          _GuideStepKind.discovery => const _DiscoveryMiniature(),
          _GuideStepKind.interest => const _InterestMiniature(),
          _GuideStepKind.conversation => const _ConversationMiniature(),
        },
      ),
    );
  }
}

class _DiscoveryMiniature extends StatelessWidget {
  const _DiscoveryMiniature();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PositionedDirectional(
          start: 4,
          top: 2,
          child: Container(
            width: 36,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.slateMist,
            ),
          ),
        ),
        PositionedDirectional(
          end: 1,
          bottom: 1,
          child: Container(
            width: 30,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.champagneGold,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 14,
              color: AppColors.readableOn(AppColors.champagneGold),
            ),
          ),
        ),
      ],
    );
  }
}

class _InterestMiniature extends StatelessWidget {
  const _InterestMiniature();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(height: 1, color: AppColors.goldBorder),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: _MiniNode(icon: Icons.person_outline_rounded),
        ),
        const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _MiniNode(icon: Icons.person_outline_rounded),
        ),
        Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Icon(
            Icons.favorite_outline_rounded,
            size: 13,
            color: AppColors.champagneGold,
          ),
        ),
      ],
    );
  }
}

class _ConversationMiniature extends StatelessWidget {
  const _ConversationMiniature();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 42,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(5),
                topEnd: Radius.circular(5),
                bottomEnd: Radius.circular(5),
              ),
              border: Border.all(color: AppColors.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(
            width: 36,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.champagneGold,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(5),
                topEnd: Radius.circular(5),
                bottomStart: Radius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniNode extends StatelessWidget {
  const _MiniNode({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Icon(icon, size: 13, color: AppColors.slateMist),
    );
  }
}
