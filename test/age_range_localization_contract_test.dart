import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic minimum and maximum survive gen_l10n placeholder ordering',
      () {
    final copy = File('lib/l10n/ui_copy.dart').readAsStringSync();
    final generated = File(
      'lib/l10n/generated/app_localizations_en.dart',
    ).readAsStringSync();

    expect(
      generated,
      contains('preferences_label_age_range(Object max, Object min)'),
    );
    expect(
      copy,
      contains('preferences_label_age_range(maximum, minimum)'),
    );
  });
}
