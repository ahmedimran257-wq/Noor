import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/utils/copy_engine.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('onboarding copy preserves every relation in $locale', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final cases = [
        (
          relations: <String?>['parent', 'guardian'],
          expected: [
            l10n.copy_hijab_parent,
            l10n.copy_beard_parent,
            l10n.copy_prayer_parent,
            l10n.onboarding_label_community_parent,
          ],
        ),
        (
          relations: <String?>['sibling'],
          expected: [
            l10n.copy_hijab_sibling,
            l10n.copy_beard_sibling,
            l10n.copy_prayer_sibling,
            l10n.onboarding_label_community_parent,
          ],
        ),
        (
          relations: <String?>['self', null, '', 'unknown'],
          expected: [
            l10n.copy_hijab_self,
            l10n.copy_beard_self,
            l10n.copy_prayer_self,
            l10n.onboarding_label_community,
          ],
        ),
      ];
      for (final entry in cases) {
        for (final relation in entry.relations) {
          expect(
            [
              CopyEngine.hijabQuestion(l10n, relation, 'female'),
              CopyEngine.beardQuestion(l10n, relation),
              CopyEngine.prayerQuestion(l10n, relation),
              CopyEngine.communityQuestion(l10n, relation),
            ],
            entry.expected,
            reason: 'relation=$relation',
          );
          expect(
            CopyEngine.hijabQuestion(l10n, relation, 'male'),
            entry.expected[1],
          );
          expect(
            CopyEngine.hijabQuestion(l10n, relation, null),
            entry.expected[0],
          );
        }
      }
    });
  }
}
