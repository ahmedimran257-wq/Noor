import 'package:flutter/widgets.dart';

import '../../theme/app_dimensions.dart';

/// Sizes a discovery card: the editorial 7:10 portrait where space is tight,
/// growing into the free height on tall phones (up to
/// [AppDimensions.cardTallestAspectRatio]) so no dead band sits under it.
class ProfileCardBox extends StatelessWidget {
  const ProfileCardBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final maxHeight = constraints.maxHeight;
      if (!width.isFinite ||
          !maxHeight.isFinite ||
          maxHeight <= width / AppDimensions.cardAspectRatio) {
        return AspectRatio(
          aspectRatio: AppDimensions.cardAspectRatio,
          child: child,
        );
      }
      final tallest = width / AppDimensions.cardTallestAspectRatio;
      return SizedBox(
        width: width,
        height: maxHeight < tallest ? maxHeight : tallest,
        child: child,
      );
    });
  }
}
