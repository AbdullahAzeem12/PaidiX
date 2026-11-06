/// Defines paidi x bottom nav bar in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';

/// Data representation of an item inside [PaidiXBottomNavBar].
class PaidiXBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const PaidiXBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// An ultra-premium, ergonomically responsive Bottom Navigation Bar
/// designed for PaidiX. Features:
/// - Fully responsive adaptive spacing across all mobile screen widths (320px–480px+).
/// - Dynamic auto-fitting typography (`FittedBox`) ensuring full text display with zero truncation,
///   no ellipsis dots (`...`), and no cut-off alphabets.
/// - Safe area padding preserving comfortable ergonomics against Android gesture bars and 3-button navs.
/// - Instant 0ms tactile spongy compression on press (`Curves.easeInOutCubic`)
///   with springy rebound on release (`Curves.easeOutBack`).
/// - Micro-indicator glow bar and fluid active pill transition.
/// - State-of-the-art animated icon transitions and scale bounce.
class PaidiXBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<PaidiXBottomNavItem> items;

  const PaidiXBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final barBg = colors.card;
    final barBorder = colors.border;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : const Color(0xFF022F32).withValues(alpha: 0.08);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isVeryNarrow = screenWidth < 340;
        final isCompact = screenWidth < 380;

        // Dynamic metrics tailored to device viewport width
        final double barHPad = isVeryNarrow ? 4.0 : (isCompact ? 8.0 : 12.0);
        final double itemHPad = isVeryNarrow ? 2.0 : (isCompact ? 3.5 : 5.0);
        final double fontSize = isVeryNarrow ? 9.5 : (isCompact ? 10.5 : 11.0);
        final double iconSize = isVeryNarrow ? 20.0 : (isCompact ? 21.0 : 22.0);
        final double indicatorWidth =
            isVeryNarrow ? 12.0 : (isCompact ? 16.0 : 18.0);

        return Container(
          decoration: BoxDecoration(
            color: barBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: barBorder, width: 1.2)),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            maintainBottomViewPadding: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                barHPad,
                6,
                barHPad,
                bottomInset > 0 ? 4 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: _NavBarTabItem(
                      item: item,
                      isSelected: isSelected,
                      fontSize: fontSize,
                      iconSize: iconSize,
                      horizontalPadding: itemHPad,
                      indicatorWidth: indicatorWidth,
                      onTap: () => onItemSelected(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavBarTabItem extends StatefulWidget {
  final PaidiXBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final double indicatorWidth;

  const _NavBarTabItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.fontSize,
    required this.iconSize,
    required this.horizontalPadding,
    required this.indicatorWidth,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<_NavBarTabItem> createState() => _NavBarTabItemState();
}

class _NavBarTabItemState extends State<_NavBarTabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    // 100ms quick compression, 240ms bouncy rebound
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  /// Records the pointer press and starts the button's pressed animation.
  void _handlePointerDown(PointerDownEvent _) {
    _bounceController.forward();
  }

  /// Ends the pressed animation and forwards the completed button interaction.
  void _handlePointerUp(PointerUpEvent _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _bounceController.reverse();
    });
  }

  /// Resets the pressed animation when the pointer gesture is cancelled.
  void _handlePointerCancel(PointerCancelEvent _) {
    if (mounted) _bounceController.reverse();
  }

  /// Starts the pressed visual state while the pointer is held down.
  void _onTapDown(TapDownDetails _) {
    _bounceController.forward();
  }

  /// Ends the pressed visual state and completes the tap callback.
  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _bounceController.reverse();
    });
  }

  /// Clears the pressed visual state when a gesture is interrupted.
  void _onTapCancel() {
    if (mounted) _bounceController.reverse();
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activePillBg = isDark
        ? AppColors.activeNavBg
        : colors.cardHighlight;
    final activePillBorder = isDark
        ? colors.aqua.withValues(alpha: 0.35)
        : colors.aqua.withValues(alpha: 0.25);
    final activeIconColor = colors.aqua;
    final inactiveIconColor = isDark
        ? colors.textMuted
        : colors.textSecondary;

    final activeTextColor = colors.textPrimary;
    final inactiveTextColor = isDark
        ? colors.textPlaceholder
        : colors.textSecondary;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Material(
            color: Colors.transparent,
            borderRadius: AppSpacing.radiusMd,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: AppSpacing.radiusMd,
              splashColor: colors.aqua.withValues(alpha: 0.18),
              highlightColor: colors.aqua.withValues(alpha: 0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: widget.horizontalPadding,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected ? activePillBg : Colors.transparent,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: widget.isSelected
                        ? activePillBorder
                        : Colors.transparent,
                    width: 1.2,
                  ),
                  boxShadow: widget.isSelected && isDark
                      ? [
                          BoxShadow(
                            color: colors.aqua.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : (widget.isSelected && !isDark
                          ? [
                              BoxShadow(
                                color: const Color(0xFF022F32)
                                    .withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Icon with state transition & bounce scale
                    AnimatedScale(
                      scale: widget.isSelected ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: child,
                        ),
                        child: Icon(
                          widget.isSelected
                              ? widget.item.activeIcon
                              : widget.item.icon,
                          key: ValueKey<bool>(widget.isSelected),
                          size: widget.iconSize,
                          color: widget.isSelected
                              ? activeIconColor
                              : inactiveIconColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Fully responsive, complete label without ellipsis or cutting
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          fontFamily: AppTheme.activeFontFamily,
                          fontSize: widget.fontSize,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: -0.2,
                          color: widget.isSelected
                              ? activeTextColor
                              : inactiveTextColor,
                          height: 1.15,
                        ),
                        child: Text(
                          widget.item.label,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Micro-Indicator Bar underneath active tab
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      height: widget.isSelected ? 2.5 : 0.0,
                      width: widget.isSelected ? widget.indicatorWidth : 0.0,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? colors.aqua
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: widget.isSelected
                            ? [
                                BoxShadow(
                                  color: colors.aqua.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
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
  }
}
