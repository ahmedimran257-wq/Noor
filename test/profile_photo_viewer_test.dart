import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/home/screens/profile_detail_screen.dart')
      .readAsStringSync();
  final viewer = source.substring(
    source.indexOf('class _FullScreenPhotoViewer extends StatefulWidget'),
    source.indexOf('// Header Icon Button'),
  );

  test('viewer follows the live gallery instead of a copied URL list', () {
    // Opening the viewer before photos 2-4 finished signing used to freeze
    // those slots on the person placeholder for the life of the viewer.
    expect(viewer, contains('ValueListenableBuilder<_GallerySnapshot>'));
    expect(viewer, isNot(contains('final List<String?> photoUrls')));
    expect(source, contains('_publishGallery();'));
    expect(viewer, contains('onImageError: onImageError'));
  });

  test('viewer text has a Material ancestor', () {
    // Without it Flutter draws the debug yellow double underline.
    expect(viewer, contains('return Material('));
    expect(viewer, contains('color: AppColors.overlayBlack87'));
  });

  test('viewer controls use theme-independent media colours', () {
    // surfaceGlass is near-white in light themes, which hid the white close
    // icon; the theme background turned the viewer into a beige box.
    expect(viewer, isNot(contains('AppColors.surfaceGlass')));
    expect(viewer, isNot(contains('AppColors.obsidianDeep')));
    expect(viewer, contains('color: AppColors.overlayBlack55'));
    expect(viewer, contains('Icons.close_rounded'));
  });
}
