/// Defines session timeout dialog in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../services/session_timeout_service.dart';
import 'spongy_tap.dart';

/// Aesthetic, theme-reactive modal dialog presented when the user has been idle
/// for 5 minutes during an active authenticated session.
///
/// Designed to meet rigorous banking security standards:
/// - Cannot be dismissed by tapping outside or via Android back gestures (PopScope).
/// - Illuminated gold timer halo and reassuring regulatory safety copy.
/// - Single tactile "Log In Again" action that cleanly resets session state and routes to /signin.
class SessionTimeoutDialog extends StatelessWidget {
  const SessionTimeoutDialog({super.key});

  /// Displays the [SessionTimeoutDialog] on top of the root navigator.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.78 : 0.58,
      ),
      builder: (ctx) => const SessionTimeoutDialog(),
    );
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = c.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Center(
        child: SingleChildScrollView(
          child: Dialog(
            backgroundColor: c.card,
            surfaceTintColor: Colors.transparent,
            elevation: 20,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark
                    ? c.border.withValues(alpha: 0.8)
                    : c.border.withValues(alpha: 0.95),
                width: 1.2,
              ),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Illuminated Glowing Timer / Lock Halo
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          c.gold.withValues(alpha: isDark ? 0.22 : 0.16),
                          c.gold.withValues(alpha: isDark ? 0.08 : 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: c.gold.withValues(alpha: isDark ? 0.50 : 0.40),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.gold.withValues(alpha: isDark ? 0.18 : 0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 28,
                      color: c.gold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Eyebrow Security Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: c.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.gold.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'SESSION EXPIRED • 5 MIN INACTIVITY',
                            style: TextStyle(
                              fontFamily: AppTheme.activeFontFamily,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: c.gold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Headline
                  Text(
                    'Session Inactivity Timeout',
                    style: TextStyle(
                      fontFamily: AppTheme.activeFontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Explanatory Copy
                  Text(
                    'You were idle for 5 minutes. For your security and financial data privacy, your active session was closed. Please sign in again to access your account.',
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Financial Security Reassurance Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? c.cardDark : c.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.border.withValues(alpha: isDark ? 0.6 : 0.8),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 20,
                          color: c.emerald,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your account funds, linked banks, and pending transfers remain 100% secure.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: c.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // "Log In Again" Spongy Primary Button
                  SpongyTap(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context, rootNavigator: true).pop();
                      SessionTimeoutService.instance.handleLogout(context);
                    },
                    pressScale: 0.965,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.primaryButton,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.aqua.withValues(alpha: isDark ? 0.45 : 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.primaryButton.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 18,
                            color: c.primaryButtonText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Log In Again',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: c.primaryButtonText,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
