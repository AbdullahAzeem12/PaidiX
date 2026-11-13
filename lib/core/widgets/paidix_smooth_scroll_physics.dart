/// Shared touch scrolling behavior for PaidiX lists and scrollable controls.

import 'package:flutter/widgets.dart';

/// Keeps scroll motion finger-led with a soft edge bounce and controlled flings.
///
/// Bouncing physics preserves the direct drag response and natural overscroll.
/// Reducing carried momentum prevents repeated quick swipes from accelerating
/// the list too aggressively, while still allowing a single swipe to coast.
class PaidiXSmoothScrollPhysics extends BouncingScrollPhysics {
  const PaidiXSmoothScrollPhysics({super.parent});

  @override
  PaidiXSmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PaidiXSmoothScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double carriedMomentum(double existingVelocity) {
    return super.carriedMomentum(existingVelocity) * 0.86;
  }
}

/// Use this on vertical page scrolls to retain pull-to-refresh when content is
/// shorter than the viewport.
const ScrollPhysics paidiXRefreshScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: PaidiXSmoothScrollPhysics(),
);

/// Use this on horizontal controls and lists that should share page motion.
const ScrollPhysics paidiXSmoothScrollPhysics = PaidiXSmoothScrollPhysics();
