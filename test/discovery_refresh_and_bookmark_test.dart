import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/widgets/cards/silarah_profile_card.dart';

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.blackWhite));

  test('filter refresh keeps one stable PageView controller attachment', () {
    final source = File(
      'lib/features/home/screens/discovery_feed_screen.dart',
    ).readAsStringSync();

    expect(
      'positions.length == 1'.allMatches(source),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      source,
      isNot(
        contains(
          'if (feedState.status != FeedStatus.refreshing) return carousel;',
        ),
      ),
    );
    expect(
      source,
      contains('if (feedState.status == FeedStatus.refreshing)'),
    );
  });

  testWidgets('bookmark control is high contrast and reflects saved state',
      (tester) async {
    AppColors.activate(SilarahThemeMode.blackWhite);

    Future<void> pumpCard({required bool saved}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SilarahProfileCard(
                  displayName: 'Member',
                  age: 28,
                  cityName: 'Kurnool',
                  isBookmarked: saved,
                  onBookmark: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCard(saved: false);
    final unsavedIcon = tester.widget<Icon>(
      find.byIcon(Icons.bookmark_outline_rounded),
    );
    expect(unsavedIcon.color, AppColors.onMedia);
    expect(find.bySemanticsLabel('Save profile'), findsOneWidget);

    await pumpCard(saved: true);
    final savedIcon = tester.widget<Icon>(
      find.byIcon(Icons.bookmark_rounded),
    );
    expect(savedIcon.color, AppColors.overlayBlack87);
    expect(find.bySemanticsLabel('Remove saved profile'), findsOneWidget);
  });
}
