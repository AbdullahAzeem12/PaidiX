import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// A tactile wrapper that imparts a soft spongy compression on press,
/// a springy bounce on release, a smooth liquid ripple, and a color transition.
class SpongyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? backgroundColor;
  final Color? activeBackgroundColor;
  final Border? border;
  final Border? activeBorder;
  final EdgeInsetsGeometry padding;
  final bool enableRipple;

  const SpongyTap({
    super.key,
    required this.child,
    required this.onTap,
    this.pressScale = 0.94,
    this.pressDuration = const Duration(milliseconds: 110),
    this.releaseDuration = const Duration(milliseconds: 260),
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    this.backgroundColor,
    this.activeBackgroundColor,
    this.border,
    this.activeBorder,
    this.padding = EdgeInsets.zero,
    this.enableRipple = true,
  });

  @override
  State<SpongyTap> createState() => _SpongyTapState();
}

class _SpongyTapState extends State<SpongyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent _) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handlePointerUp(PointerUpEvent _) {
    if (widget.onTap != null) {
      // Hold compression briefly so fast taps register a full spongy squash & bounce
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _controller.reverse();
      });
    }
  }

  void _handlePointerCancel(PointerCancelEvent _) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _controller.reverse();
      });
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = widget.borderRadius ?? AppSpacing.radiusSm;
    final splash = widget.splashColor ?? colors.aqua.withValues(alpha: 0.20);
    final highlight =
        widget.highlightColor ?? colors.aqua.withValues(alpha: 0.08);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final currentScale = _scaleAnimation.value;

          Color? currentBg;
          if (widget.backgroundColor != null ||
              widget.activeBackgroundColor != null) {
            final startBg = widget.backgroundColor ?? Colors.transparent;
            final endBg = widget.activeBackgroundColor ??
                widget.backgroundColor ??
                Colors.transparent;
            currentBg = Color.lerp(startBg, endBg, progress);
          }

          Border? currentBorder;
          if (widget.border != null && widget.activeBorder != null) {
            currentBorder =
                Border.lerp(widget.border, widget.activeBorder, progress);
          } else {
            currentBorder = widget.border;
          }

          return Transform.scale(
            scale: currentScale,
            child: Material(
              color: currentBg ?? Colors.transparent,
              borderRadius: radius,
              clipBehavior:
                  radius != BorderRadius.zero ? Clip.antiAlias : Clip.none,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                borderRadius: radius,
                splashFactory: widget.enableRipple
                    ? InkRipple.splashFactory
                    : NoSplash.splashFactory,
                splashColor: splash,
                highlightColor: highlight,
                child: Container(
                  padding: widget.padding,
                  decoration: currentBorder != null
                      ? BoxDecoration(
                          borderRadius: radius,
                          border: currentBorder,
                        )
                      : null,
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A spongy link text button for secondary actions ("Forgot password?",
/// "Create an account", "Sign in") featuring tactile squish, bounce, ripple,
/// and smooth color illumination.
class SpongyLinkButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;
  final Color? normalColor;
  final Color? activeColor;
  final EdgeInsetsGeometry padding;

  const SpongyLinkButton({
    super.key,
    required this.text,
    required this.onTap,
    this.style,
    this.normalColor,
    this.activeColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  });

  @override
  State<SpongyLinkButton> createState() => _SpongyLinkButtonState();
}

class _SpongyLinkButtonState extends State<SpongyLinkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _controller.reverse();
      });
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final baseNormal = widget.normalColor ?? colors.aqua;
    final baseActive = widget.activeColor ?? colors.aquaLight;
    final baseStyle = widget.style ?? AppTypography.linkText;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final currentScale = _scaleAnimation.value;
        final currentColor = Color.lerp(baseNormal, baseActive, progress)!;

        return Transform.scale(
          scale: currentScale,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              borderRadius: BorderRadius.circular(6),
              splashFactory: InkRipple.splashFactory,
              splashColor: colors.aqua.withValues(alpha: 0.18),
              highlightColor: colors.aqua.withValues(alpha: 0.08),
              child: Padding(
                padding: widget.padding,
                child: Text(
                  widget.text,
                  style: baseStyle.copyWith(color: currentColor),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
