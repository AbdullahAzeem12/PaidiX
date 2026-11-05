/// Defines app button in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, text, success }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final AppButtonVariant variant;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.width,
    this.height = 46.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    // 110ms soft spongy compression, 260ms springy bounce rebound
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.945, // Soft spongy squish
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack, // Delightful spring bounce on release
      ),
    );
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Records the pointer press and starts the button's pressed animation.
  void _handlePointerDown(PointerDownEvent _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  /// Ends the pressed animation and forwards the completed button interaction.
  void _handlePointerUp(PointerUpEvent _) {
    if (widget.onPressed != null && !widget.isLoading) {
      // Hold compression briefly so fast taps register a full spongy squash and bounce
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _controller.reverse();
      });
    }
  }

  /// Resets the pressed animation when the pointer gesture is cancelled.
  void _handlePointerCancel(PointerCancelEvent _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Color normalBg;
    Color activeBg;
    Color normalFg;
    Color activeFg;
    Color normalBorderColor;
    Color activeBorderColor;
    double borderWidth = 1.1;
    Color splashColor;
    Color highlightColor;
    bool showGlow = false;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        normalBg = isEnabled
            ? colors.primaryButton
            : colors.primaryButton.withValues(alpha: 0.4);
        activeBg = isEnabled
            ? colors.primaryButtonHover
            : colors.primaryButton.withValues(alpha: 0.4);
        normalFg = colors.primaryButtonText;
        activeFg = colors.primaryButtonText;
        normalBorderColor = colors.borderFocused.withValues(alpha: 0.3);
        activeBorderColor = colors.borderFocused;
        splashColor = colors.aquaLight.withValues(alpha: 0.28);
        highlightColor = colors.aqua.withValues(alpha: 0.12);
        showGlow = true;
        break;
      case AppButtonVariant.secondary:
        normalBg = isEnabled ? colors.card : colors.cardDark;
        activeBg = isEnabled ? colors.cardHighlight : colors.cardDark;
        normalFg = colors.textPrimary;
        activeFg = colors.aquaLight;
        normalBorderColor = colors.borderSubtle;
        activeBorderColor = colors.aqua.withValues(alpha: 0.65);
        borderWidth = 1.2;
        splashColor = colors.aqua.withValues(alpha: 0.18);
        highlightColor = colors.aqua.withValues(alpha: 0.08);
        showGlow = true;
        break;
      case AppButtonVariant.outline:
        normalBg = Colors.transparent;
        activeBg = colors.aqua.withValues(alpha: 0.12);
        normalFg = colors.textPrimary;
        activeFg = colors.aquaLight;
        normalBorderColor = colors.border;
        activeBorderColor = colors.aqua;
        borderWidth = 1.2;
        splashColor = colors.aqua.withValues(alpha: 0.20);
        highlightColor = colors.aqua.withValues(alpha: 0.08);
        break;
      case AppButtonVariant.text:
        normalBg = Colors.transparent;
        activeBg = colors.aqua.withValues(alpha: 0.10);
        normalFg = colors.textSecondary;
        activeFg = colors.aquaLight;
        normalBorderColor = Colors.transparent;
        activeBorderColor = Colors.transparent;
        borderWidth = 0.0;
        splashColor = colors.aqua.withValues(alpha: 0.16);
        highlightColor = colors.aqua.withValues(alpha: 0.06);
        break;
      case AppButtonVariant.success:
        normalBg = isEnabled ? colors.aquaDark : colors.cardHighlight;
        activeBg = isEnabled ? colors.primaryButtonHover : colors.cardHighlight;
        normalFg = colors.primaryButtonText;
        activeFg = colors.primaryButtonText;
        normalBorderColor = colors.borderFocused.withValues(alpha: 0.4);
        activeBorderColor = colors.borderFocused;
        borderWidth = 1.2;
        splashColor = colors.aquaLight.withValues(alpha: 0.30);
        highlightColor = colors.aqua.withValues(alpha: 0.12);
        showGlow = true;
        break;
    }

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
          final currentBg = Color.lerp(normalBg, activeBg, progress)!;
          final currentBorderColor =
              Color.lerp(normalBorderColor, activeBorderColor, progress)!;
          final currentFg = Color.lerp(normalFg, activeFg, progress)!;

          return Transform.scale(
            scale: currentScale,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: AppSpacing.radiusMd,
                boxShadow: [
                  if (showGlow && isEnabled && progress > 0.01)
                    BoxShadow(
                      color: colors.aqua.withValues(alpha: 0.35 * progress),
                      blurRadius: 16 * progress,
                      spreadRadius: 1.5 * progress,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Material(
                color: currentBg,
                borderRadius: AppSpacing.radiusMd,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isEnabled ? widget.onPressed : null,
                  borderRadius: AppSpacing.radiusMd,
                  splashFactory: InkRipple.splashFactory,
                  splashColor: splashColor,
                  highlightColor: highlightColor,
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      borderRadius: AppSpacing.radiusMd,
                      border: borderWidth > 0
                          ? Border.all(
                              color: currentBorderColor,
                              width: borderWidth,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: IconTheme(
                      data: IconThemeData(color: currentFg, size: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.isLoading) ...[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(currentFg),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else if (widget.icon != null) ...[
                            widget.icon!,
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              widget.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.buttonText.copyWith(
                                color: currentFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
