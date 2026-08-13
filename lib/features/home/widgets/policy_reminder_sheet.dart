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
      barrierColor: AppColors.obsidianNight.withValues(alpha: 0.86),
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
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppColors.champagneGold.withValues(alpha: 0.48),
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.space24,
            AppDimensions.space24,
            AppDimensions.space24,
            AppDimensions.space24 + bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                      border: Border.all(
                        color: AppColors.champagneGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.gpp_good_outlined,
                      color: AppColors.champagneGold,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(
                          context.uiCopy(
                            "A reminder about Silarah's rules",
                          ),
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space6),
                        UiText(
                          context.uiCopy(
                            'Please review these important safety and account rules.',
                          ),
                          style: AppTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),
              _ReminderRule(
                icon: Icons.favorite_outline_rounded,
                text: context.uiCopy(
                  'Use Silarah only for genuine matrimonial introductions and keep your profile truthful.',
                ),
              ),
              _ReminderRule(
                icon: Icons.shield_outlined,
                text: context.uiCopy(
                  'Harassment, scams, sexual content, child harm and requests for money are prohibited.',
                ),
              ),
              _ReminderRule(
                icon: Icons.rule_rounded,
                text: context.uiCopy(
                  'Content or accounts that break the rules may be removed or suspended. Unlawful conduct may be reported.',
                ),
              ),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space4,
                children: [
                  TextButton(
                    onPressed: () => _open(LegalDocuments.terms.id),
                    child: UiText(context.uiCopy('Read Terms')),
                  ),
                  TextButton(
                    onPressed: () => _open(LegalDocuments.privacy.id),
                    child: UiText(context.uiCopy('Read Privacy')),
                  ),
                  TextButton(
                    onPressed: () => _open(LegalDocuments.community.id),
                    child: UiText(context.uiCopy('Read Guidelines')),
                  ),
                ],
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
                    color: AppColors.champagneGold,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusButton,
                    ),
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
                      : UiText(
                          context.uiCopy('I understand'),
                          style: AppTypography.button,
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

class _ReminderRule extends StatelessWidget {
  const _ReminderRule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.space10),
      padding: const EdgeInsets.all(AppDimensions.space14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.champagneGold, size: 20),
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
