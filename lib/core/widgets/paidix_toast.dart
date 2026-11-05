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
/// Provides auto-dismissing, responsive, and tactile notifications that
/// match the PaidiX Abyssal Teal / Gold / Emerald / Rose visual language.
class PaidiXToast {
  PaidiXToast._();

  /// Displays a success toast notification (Emerald accent, auto-dismiss in 2.8s).
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

  /// Displays a warning toast notification (Amber accent, auto-dismiss in 3.2s).
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

  /// Displays an error toast notification (Rose accent, auto-dismiss in 3.5s).
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

  /// Displays a server error notification with an optional retry callback.
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

  /// Displays an informational toast notification (Aqua accent, auto-dismiss in 2.5s).
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

  /// Base presentation method that builds and shows the themed [SnackBar].
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

    final effectiveTitle = title ?? (type == PaidiXToastType.info ? null : defaultTitle);

    // Subtle tactile feedback on trigger
    if (type == PaidiXToastType.error || type == PaidiXToastType.serverError) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final snackBar = SnackBar(
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
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  iconData,
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
                  if (effectiveTitle != null) ...[
                    Text(
                      effectiveTitle,
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
                    message,
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              SpongyTap(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    actionLabel,
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
              onTap: () => messenger.hideCurrentSnackBar(),
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
      ),
    );

    messenger.showSnackBar(snackBar);
  }
}
