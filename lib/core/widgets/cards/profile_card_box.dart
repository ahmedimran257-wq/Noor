import 'package:flutter/widgets.dart';

import '../../theme/app_dimensions.dart';

/// Sizes a discovery card to the space it is given.
///
/// - Tall phones: grows from the editorial 7:10 portrait up to
///   [AppDimensions.cardTallestAspectRatio] so no dead band sits under it.
/// - Short (16:9) phones: keeps the full width and uses the available height,
///   down to [AppDimensions.cardSquarestAspectRatio]. Holding 7:10 there made
///   the card narrower than the screen and pushed it to one side.
/// - Anything shorter still: keeps the squarest shape, centred.
class ProfileCardBox extends StatelessWidget {
  const ProfileCardBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final maxHeight = constraints.maxHeight;
      if (!width.isFinite || !maxHeight.isFinite) {
        return AspectRatio(
          aspectRatio: AppDimensions.cardAspectRatio,
          child: child,
        );
      }

      final tallest = width / AppDimensions.cardTallestAspectRatio;
      final squarest = width / AppDimensions.cardSquarestAspectRatio;
      if (maxHeight >= squarest) {
        return SizedBox(
          width: width,
          height: maxHeight < tallest ? maxHeight : tallest,
          child: child,
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: AppDimensions.cardSquarestAspectRatio,
          child: child,
        ),
      );
    });
  }
}
