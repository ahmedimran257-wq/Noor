import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/widgets/cards/silarah_profile_card.dart';

void main() {
  testWidgets('Discovery Hero contains media only and never card text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SilarahProfileCard(
                displayName: 'Transition Test',
                age: 29,
                cityName: 'Kurnool',
                photoHeroTag: 'profile_photo_test',
              ),
            ),
          ),
        ),
      ),
    );

    final hero = find.byType(Hero);
    expect(hero, findsOneWidget);
    expect(find.text('Transition Test'), findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.text('Transition Test')),
      findsNothing,
    );
    expect(
      tester.widget<Hero>(hero).tag,
      'profile_photo_test',
    );
  });
}
