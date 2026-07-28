import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/models/discovery_profile.dart';
import 'package:silarah/features/home/screens/profile_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('profile transport preserves every ordered authorized photo', () {
    const profile = DiscoveryProfile(
      id: '00000000-0000-0000-0000-000000000123',
      firstName: 'Amina',
      lastNameInitial: 'K',
      age: 27,
      cityName: 'Hyderabad',
      photoUrl: 'https://example.com/primary.jpg',
      photoUrls: [
        'https://example.com/primary.jpg',
        'https://example.com/second.jpg',
      ],
      photoCount: 2,
    );

    expect(profile.orderedPhotoUrls, [
      'https://example.com/primary.jpg',
      'https://example.com/second.jpg',
    ]);
    expect(profile.copyWith().orderedPhotoUrls.length, 2);
  });

  test('own preview loads real slots and the gallery renders each URL', () {
    final profileScreen =
        File('lib/features/home/screens/my_profile_screen.dart')
            .readAsStringSync();
    final detailScreen = File(
      'lib/features/home/screens/profile_detail_screen.dart',
    ).readAsStringSync();
    final photoService =
        File('lib/core/services/profile_photo_service.dart').readAsStringSync();

    expect(profileScreen, contains('getMyPhotoSlots()'));
    expect(profileScreen, contains('photoUrls: galleryUrls'));
    expect(profileScreen, contains('if (_profilePreviewOpening) return;'));
    expect(
      profileScreen,
      contains('onTap: previewOpening ? null : onPreview'),
    );
    expect(
      profileScreen,
      contains('await _performOpenOwnProfilePreview();'),
    );
    expect(detailScreen, contains('photoUrl: i < photoUrls.length'));
    expect(detailScreen, isNot(contains('photoUrl != null && index == 0')));
    expect(detailScreen, contains('controller.nextPage'));
    expect(detailScreen, contains("'\${currentPage + 1} / \$totalPhotos'"));
    expect(detailScreen, contains('Member preview'));
    expect(detailScreen, contains('_OwnProfileActionBar'));
    expect(profileScreen, contains('onManageOwnPhotos:'));
    expect(photoService, contains('getVisiblePhotoSlots'));
    expect(photoService, contains("'purpose': 'read_profile_gallery'"));
    expect(photoService, isNot(contains('profiles!inner')));
  });

  testWidgets('profile preview exposes and navigates every gallery photo',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const profile = DiscoveryProfile(
      id: '00000000-0000-0000-0000-000000000123',
      firstName: 'Amina',
      lastNameInitial: 'K',
      age: 27,
      cityName: 'Hyderabad',
      photoUrls: [
        'https://example.com/primary.jpg',
        'https://example.com/second.jpg',
      ],
      photoCount: 2,
    );

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => InterestsCubit(),
        child: const MaterialApp(
          home: ProfileDetailScreen(
            profile: profile,
            heroTag: 'gallery-test',
            isInterestSent: false,
            onInterestSent: _noop,
            isOwnProfile: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
  });
}

void _noop() {}
