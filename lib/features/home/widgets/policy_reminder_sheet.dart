import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/legal/legal_documents.dart';
import '../../../core/services/policy_reminder_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../screens/legal_doc_screen.dart';

class PolicyReminderSheet {
  const PolicyReminderSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      // A neutral scrim preserves contrast in every visual identity. Using the
      // page background here washed the underlying screen white in light mode.
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (_) => const _PolicyReminderContent(),
    );
  }
}

class _PolicyReminderContent extends StatefulWidget {
  const _PolicyReminderContent();

  @override
  State<_PolicyReminderContent> createState() => _PolicyReminderContentState();
}

class _PolicyReminderContentState extends State<_PolicyReminderContent> {
  bool _saving = false;
  bool _saveFailed = false;

  Future<void> _acknowledge() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await PolicyReminderService.instance.acknowledge();
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = true;
    });
  }

  void _open(String type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalDocScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.uiCopy("A reminder about Silarah's rules"),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.goldBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 36,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.space24,
            AppDimensions.space12,
            AppDimensions.space24,
            AppDimensions.space24 + bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusTiny),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              _ReminderHero(
                title: context.uiCopy("A reminder about Silarah's rules"),
                subtitle: context.uiCopy(
                  'Please review these important safety and account rules.',
                ),
              ),
              const SizedBox(height: AppDimensions.space20),
              _ReminderRulesPanel(
                rules: [
                  (
                    Icons.favorite_outline_rounded,
                    context.uiCopy(
                      'Use Silarah only for genuine matrimonial introductions and keep your profile truthful.',
                    ),
                  ),
                  (
                    Icons.shield_outlined,
                    context.uiCopy(
                      'Harassment, scams, sexual content, child harm and requests for money are prohibited.',
                    ),
                  ),
                  (
                    Icons.rule_rounded,
                    context.uiCopy(
                      'Content or accounts that break the rules may be removed or suspended. Unlawful conduct may be reported.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),
              Row(
                children: [
                  Expanded(
                    child: _LegalAction(
                      icon: Icons.description_outlined,
                      label: context.uiCopy('Read Terms'),
                      onTap: () => _open(LegalDocuments.terms.id),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: _LegalAction(
                      icon: Icons.lock_outline_rounded,
                      label: context.uiCopy('Read Privacy'),
                      onTap: () => _open(LegalDocuments.privacy.id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space8),
              _LegalAction(
                icon: Icons.groups_outlined,
                label: context.uiCopy('Read Guidelines'),
                onTap: () => _open(LegalDocuments.community.id),
              ),
              if (_saveFailed) ...[
                const SizedBox(height: AppDimensions.space8),
                UiText(
                  context.uiCopy(
                    'We could not save your acknowledgement. Check your connection and try again.',
                  ),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.errorRed,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.space14),
              SilarahPressable(
                semanticLabel: context.uiCopy('I understand'),
                enabled: !_saving,
                onTap: _acknowledge,
                child: Container(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.champagneLight,
                        AppColors.champagneGold,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.champagneGold.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.readableOn(
                              AppColors.champagneGold,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            UiText(
                              context.uiCopy('I understand'),
                              style: AppTypography.button,
                            ),
                            const SizedBox(width: AppDimensions.space8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: AppDimensions.iconSizeMedium,
                              color: AppColors.readableOn(
                                AppColors.champagneGold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderHero extends StatelessWidget {
  const _ReminderHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.champagneGold.withValues(alpha: 0.16),
            AppColors.surfacePanelTop,
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.champagneGold,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              boxShadow: [
                BoxShadow(
                  color: AppColors.champagneGold.withValues(alpha: 0.18),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(
              Icons.gpp_good_rounded,
              color: AppColors.readableOn(AppColors.champagneGold),
              size: 28,
            ),
          ),
          const SizedBox(width: AppDimensions.space14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  title,
                  style: AppTypography.screenTitle.copyWith(fontSize: 23),
                ),
                const SizedBox(height: AppDimensions.space6),
                UiText(subtitle, style: AppTypography.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRulesPanel extends StatelessWidget {
  const _ReminderRulesPanel({required this.rules});

  final List<(IconData, String)> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rules.length; index++) ...[
            _ReminderRule(
              index: index + 1,
              icon: rules[index].$1,
              text: rules[index].$2,
            ),
            if (index != rules.length - 1)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 68),
                child: Divider(height: 1, color: AppColors.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReminderRule extends StatelessWidget {
  const _ReminderRule({
    required this.index,
    required this.icon,
    required this.text,
  });

  final int index;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                ),
                child: Icon(icon,
                    color: AppColors.champagneGold,
                    size: AppDimensions.iconSizeMedium),
              ),
              PositionedDirectional(
                top: -7,
                end: -7,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceGlass, width: 2),
                  ),
                  child: UiText(
                    '$index',
                    style: AppTypography.badge.copyWith(
                      fontSize: 8,
                      color: AppColors.readableOn(AppColors.champagneGold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: UiText(
              text,
              style: AppTypography.body.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalAction extends StatelessWidget {
  const _LegalAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeSmall),
            const SizedBox(width: AppDimensions.space8),
            Flexible(
              child: UiText(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: AppTypography.captionMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
