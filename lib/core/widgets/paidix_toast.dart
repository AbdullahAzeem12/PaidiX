/// Defines paidix toast in the application core utilities and reusable widgets.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import 'spongy_tap.dart';

enum PaidiXToastType {
  success,
  warning,
  error,
  serverError,
  info,
}

/// Unified, brand-aligned alert and toast system for PaidiX.
///
/// Features:
/// - Repositioned at the TOP of the screen (under status bar / safe area)
/// - Fluid slide-down and fade-in entrance with curved physics
/// - Tactile haptics matching semantic severity
/// - Auto-dismiss with configurable duration (emerald, amber, rose, aqua)
/// - Interactive inline actions (e.g., spongy RETRY button)
/// - Manual dismiss via (X) button or swipe-up gesture
/// - Zero-queue lag: immediately replaces previous toast
class PaidiXToast {
  PaidiXToast._();

  static OverlayEntry? _currentEntry;

  /// Immediately dismisses any active top toast notification.
  static void dismissCurrent() {
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }

  /// Displays a success toast notification (Emerald accent, auto-dismiss in 2.8s) at the top of the screen.
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: PaidiXToastType.success,
      duration: duration,
    );
  }

  /// Displays a warning toast notification (Amber accent, auto-dismiss in 3.2s) at the top of the screen.
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: PaidiXToastType.warning,
      duration: duration,
    );
  }

  /// Displays an error toast notification (Rose accent, auto-dismiss in 3.5s) at the top of the screen.
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: PaidiXToastType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Displays a server error notification with an optional retry callback at the top of the screen.
  static void showServerError(
    BuildContext context, {
    String message =
        'Unable to connect to settlement servers. Please check your connection and retry.',
    String? errorCode,
    Duration duration = const Duration(milliseconds: 4000),
    VoidCallback? onRetry,
  }) {
    show(
      context,
      message: errorCode != null ? '$message ($errorCode)' : message,
      title: 'SERVER INTERRUPTED',
      type: PaidiXToastType.serverError,
      duration: duration,
      actionLabel: onRetry != null ? 'RETRY' : null,
      onAction: onRetry,
    );
  }

  /// Displays an informational toast notification (Aqua accent, auto-dismiss in 2.5s) at the top of the screen.
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: PaidiXToastType.info,
      duration: duration,
    );
  }

  /// Base presentation method that builds and shows the themed top toast overlay.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    PaidiXToastType type = PaidiXToastType.info,
    Duration duration = const Duration(milliseconds: 3000),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine semantic accent color and icon
    final Color accentColor;
    final IconData iconData;
    final String defaultTitle;

    switch (type) {
      case PaidiXToastType.success:
        accentColor = colors.statusCompletedDot; // Emerald #10B981
        iconData = Icons.check_circle_rounded;
        defaultTitle = 'SUCCESS';
        break;
      case PaidiXToastType.warning:
        accentColor = colors.statusPendingDot; // Amber #F59E0B
        iconData = Icons.warning_amber_rounded;
        defaultTitle = 'ATTENTION';
        break;
      case PaidiXToastType.error:
        accentColor = colors.statusErrorDot; // Rose / Red #E11D48
        iconData = Icons.error_outline_rounded;
        defaultTitle = 'ERROR';
        break;
      case PaidiXToastType.serverError:
        accentColor = colors.statusErrorDot;
        iconData = Icons.cloud_off_rounded;
        defaultTitle = 'SERVER ERROR';
        break;
      case PaidiXToastType.info:
        accentColor = colors.aqua;
        iconData = Icons.info_outline_rounded;
        defaultTitle = 'NOTICE';
        break;
    }

    final effectiveTitle =
        title ?? (type == PaidiXToastType.info ? null : defaultTitle);

    // Subtle tactile feedback on trigger
    if (type == PaidiXToastType.error ||
        type == PaidiXToastType.serverError) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Dismiss any previously showing top toast immediately
    dismissCurrent();

    // Clear legacy snackbars if present
    try {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    } catch (_) {}

    // Find the nearest or root Overlay
    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);

    if (overlay == null) {
      _showFallbackSnackBar(
        context,
        message: message,
        effectiveTitle: effectiveTitle,
        accentColor: accentColor,
        iconData: iconData,
        colors: colors,
        isDark: isDark,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );
      return;
    }

    late final OverlayEntry entry;
    bool isRemoved = false;

    void safeRemove() {
      if (isRemoved) return;
      isRemoved = true;
      try {
        entry.remove();
      } catch (_) {}
      if (_currentEntry == entry) {
        _currentEntry = null;
      }
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        return _TopToastWidget(
          key: const ValueKey('paidix_top_toast_widget'),
          message: message,
          title: effectiveTitle,
          type: type,
          accentColor: accentColor,
          iconData: iconData,
          colors: colors,
          isDark: isDark,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
          onDismiss: safeRemove,
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Uses a standard SnackBar when the overlay-based toast cannot be shown.
  static void _showFallbackSnackBar(
    BuildContext context, {
    required String message,
    String? effectiveTitle,
    required Color accentColor,
    required IconData iconData,
    required PaidiXColorScheme colors,
    required bool isDark,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: duration,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A3134) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.45 : 0.65),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(iconData, color: accentColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (effectiveTitle != null)
                      Text(
                        effectiveTitle,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      message,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  child: Text(actionLabel, style: TextStyle(color: accentColor)),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => messenger.hideCurrentSnackBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final PaidiXToastType type;
  final Color accentColor;
  final IconData iconData;
  final PaidiXColorScheme colors;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    super.key,
    required this.message,
    this.title,
    required this.type,
    required this.accentColor,
    required this.iconData,
    required this.colors,
    required this.isDark,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismiss,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController.forward().then((_) {
      if (!mounted || _isDismissing) return;
      _dismissTimer = Timer(widget.duration, () {
        if (!mounted || _isDismissing) return;
        dismissWithAnimation();
      });
    });
  }

  /// Dismisses the active toast after its slide-out animation completes.
  void dismissWithAnimation() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  /// Removes the active toast without animation, such as during disposal.
  void dismissImmediately() {
    if (_isDismissing) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    _animController.stop();
    widget.onDismiss();
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Dismissible(
                      key: const Key('paidix_toast_dismissible'),
                      direction: DismissDirection.up,
                      onDismissed: (_) => dismissImmediately(),
                      child: _buildCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the card section of this interface.
  Widget _buildCard() {
    final isDark = widget.isDark;
    final colors = widget.colors;
    final accentColor = widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A3134) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.45 : 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Glowing Halo Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.40),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                widget.iconData,
                color: accentColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Message column
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null) ...[
                  Text(
                    widget.title!,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  widget.message,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Optional Action (e.g. "RETRY")
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(width: 8),
            SpongyTap(
              onTap: () {
                dismissImmediately();
                widget.onAction!();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.actionLabel!,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(width: 6),
          // Quick dismiss (X)
          SpongyTap(
            onTap: dismissWithAnimation,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: colors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
