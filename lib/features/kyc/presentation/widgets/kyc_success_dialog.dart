/// Defines kyc success dialog in the kyc feature's presentation layer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../profile/data/user_profile_repository.dart';

class KycSuccessDialog extends StatefulWidget {
  final bool resubmission;

  const KycSuccessDialog({super.key, this.resubmission = false});

  /// Displays the dialog with a springy scale + fade entrance transition
  static Future<void> show(
    BuildContext context, {
    bool resubmission = false,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'KYC Success',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 360),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) =>
          KycSuccessDialog(resubmission: resubmission),
    );
  }

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<KycSuccessDialog> createState() => _KycSuccessDialogState();
}

class _KycSuccessDialogState extends State<KycSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _iconScale;
  late final Animation<double> _glowFade;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _iconScale = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.1, 0.85, curve: Curves.elasticOut),
    );

    _glowFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Closes the KYC success dialog and navigates to the dashboard.
  ///
  /// Local submission is never treated as admin approval. Onboarding stays
  /// visible until the server marks the account verified.
  void _onContinue() {
    HapticFeedback.mediumImpact();
    UserProfileRepository.instance.markKycPendingReview();
    Navigator.of(context).pop();
    context.go(widget.resubmission ? '/app/onboarding' : '/app/dashboard');
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: colors.card,
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side:
            BorderSide(color: colors.border.withValues(alpha: 0.8), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── Animated Glowing Checkmark ─────────────────────────
              AnimatedBuilder(
                animation: _animController,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.emerald.withValues(alpha: 0.12),
                    border: Border.all(
                      color: colors.emerald.withValues(alpha: 0.5),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.emerald.withValues(alpha: 0.22),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: colors.emerald,
                    ),
                  ),
                ),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _iconScale.value,
                    child: Opacity(
                      opacity: _glowFade.value,
                      child: child,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ─── Concise Title ──────────────────────────────────────
              Text(
                widget.resubmission
                    ? 'Documents Resubmitted'
                    : 'Account Setup Complete!',
                style: TextStyle(
                  fontFamily: AppTheme.activeFontFamily,
                  color: colors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // ─── Important Information Only ─────────────────────────
              Text(
                widget.resubmission
                    ? 'Your updated identity documents have been submitted for review.'
                    : 'Your identity & bank details have been securely submitted.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // ─── Compact Status Pill ────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.emerald.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: colors.emerald,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Submitted & Under Review',
                        style: TextStyle(
                          color: colors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Spongy Action Button with Feedback ─────────────────
              SpongyTap(
                onTap: _onContinue,
                pressScale: 0.95,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? colors.aqua : colors.brand900,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? colors.aqua : colors.brand900)
                            .withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.resubmission
                                ? Icons.assignment_turned_in_rounded
                                : Icons.dashboard_rounded,
                            size: 16,
                            color:
                                isDark ? const Color(0xFF021B19) : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.resubmission
                                ? 'Return to Onboarding'
                                : 'Go to Dashboard',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF021B19)
                                  : Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
