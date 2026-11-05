/// Defines smooth animated list item in the payments feature's presentation layer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/spongy_tap.dart';

/// Ultra-smooth animated list item wrapper designed for recycler-view-like lists.
/// Provides:
/// - Dynamic pop-in (subtle spring scale 0.93 -> 1.0)
/// - Fade-in (opacity 0.0 -> 1.0)
/// - Smooth vertical slide translation (Offset(0, 0.06) -> Offset.zero)
/// - Staggered entrance timing based on list index
/// - Tactile spongy rebound on user tap
class SmoothAnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final VoidCallback? onTap;

  const SmoothAnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.onTap,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<SmoothAnimatedListItem> createState() => _SmoothAnimatedListItemState();
}

class _SmoothAnimatedListItemState extends State<SmoothAnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    final curve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(curve);

    // Staggered entry delay to create fluid wave pop-in
    final staggerMs = (widget.index % 10) * 35;
    if (staggerMs > 0) {
      Future.delayed(Duration(milliseconds: staggerMs), () {
        if (mounted) _animController.forward();
      });
    } else {
      _animController.forward();
    }
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SpongyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            pressScale: 0.985,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

