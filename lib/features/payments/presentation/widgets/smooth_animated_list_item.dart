/// Defines smooth animated list item in the payments feature's presentation layer.

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/spongy_tap.dart';

/// Recycler-view-like row animation with viewport-aware transitions.
///
/// Rows fade and pop into view while scrolling in either direction, then fade
/// and scale back slightly as they leave the viewport. The row stays mounted so
/// its state, tap rebound, and existing navigation behavior are preserved.
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

  @override
  State<SmoothAnimatedListItem> createState() => _SmoothAnimatedListItemState();
}

class _SmoothAnimatedListItemState extends State<SmoothAnimatedListItem>
    with SingleTickerProviderStateMixin {
  static const double _enterThreshold = 0.58;
  static const double _leaveThreshold = 0.32;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _faceFrontAnimation;

  final GlobalKey _rowKey = GlobalKey();
  ScrollPosition? _scrollPosition;
  Timer? _staggerTimer;
  bool _hasObservedVisibility = false;
  bool _isVisible = false;
  bool _visibilityCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 290),
      reverseDuration: const Duration(milliseconds: 230),
    );

    final curve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.42, end: 1).animate(curve);
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(curve);
    _faceFrontAnimation = Tween<double>(begin: -0.035, end: 0).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (identical(nextPosition, _scrollPosition)) {
      _scheduleVisibilityCheck();
      return;
    }

    _scrollPosition?.removeListener(_handleScroll);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_handleScroll);
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant SmoothAnimatedListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_hasObservedVisibility) {
      _scheduleVisibilityCheck();
    }
  }

  void _handleScroll() => _scheduleVisibilityCheck();

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (mounted) _updateVisibility();
    });
  }

  void _updateVisibility() {
    final position = _scrollPosition;
    if (position == null) {
      // Retain the entrance animation for uses outside a Scrollable.
      _setVisible(true, initialObservation: !_hasObservedVisibility);
      return;
    }

    final rowObject = _rowKey.currentContext?.findRenderObject();
    if (rowObject is! RenderBox || !rowObject.attached || !rowObject.hasSize) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(rowObject);
    if (viewport == null) {
      _setVisible(true, initialObservation: !_hasObservedVisibility);
      return;
    }
    final viewportBox = viewport as RenderBox;
    if (!viewportBox.attached || !viewportBox.hasSize) {
      _setVisible(true, initialObservation: !_hasObservedVisibility);
      return;
    }

    final visibleFraction = _visibleFraction(
      row: rowObject,
      viewport: viewportBox,
      axis:
          position.axisDirection == AxisDirection.left ||
              position.axisDirection == AxisDirection.right
          ? Axis.horizontal
          : Axis.vertical,
    );

    final shouldBeVisible = !_hasObservedVisibility
        ? visibleFraction > 0.05
        : _isVisible
        ? visibleFraction > _leaveThreshold
        : visibleFraction >= _enterThreshold;
    _setVisible(shouldBeVisible, initialObservation: !_hasObservedVisibility);
  }

  double _visibleFraction({
    required RenderBox row,
    required RenderBox viewport,
    required Axis axis,
  }) {
    final rowStart = row.localToGlobal(Offset.zero);
    final rowEnd = row.localToGlobal(Offset(row.size.width, row.size.height));
    final viewportStart = viewport.localToGlobal(Offset.zero);
    final viewportEnd = viewport.localToGlobal(
      Offset(viewport.size.width, viewport.size.height),
    );

    final start = axis == Axis.vertical ? rowStart.dy : rowStart.dx;
    final end = axis == Axis.vertical ? rowEnd.dy : rowEnd.dx;
    final viewportMin = axis == Axis.vertical
        ? viewportStart.dy
        : viewportStart.dx;
    final viewportMax = axis == Axis.vertical ? viewportEnd.dy : viewportEnd.dx;
    final extent = end - start;
    if (extent <= 0) return 0;

    final intersection = math.max(
      0.0,
      math.min(end, viewportMax) - math.max(start, viewportMin),
    );
    return (intersection / extent).clamp(0.0, 1.0).toDouble();
  }

  void _setVisible(bool visible, {required bool initialObservation}) {
    if (_hasObservedVisibility && visible == _isVisible) return;

    _hasObservedVisibility = true;
    _isVisible = visible;
    _staggerTimer?.cancel();

    if (!visible) {
      _animController.reverse();
      return;
    }

    if (initialObservation && widget.index > 0) {
      final delay = Duration(milliseconds: (widget.index % 8) * 28);
      if (delay > Duration.zero) {
        _staggerTimer = Timer(delay, () {
          if (mounted && _isVisible) _animController.forward();
        });
        return;
      }
    }
    _animController.forward();
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _scrollPosition?.removeListener(_handleScroll);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, _) {
        // Re-evaluate after layout changes such as orientation or window resize.
        _scheduleVisibilityCheck();
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: AnimatedBuilder(
              animation: _faceFrontAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SpongyTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onTap?.call();
                  },
                  pressScale: 0.985,
                  child: SizedBox(key: _rowKey, child: widget.child),
                ),
              ),
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_faceFrontAnimation.value),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
