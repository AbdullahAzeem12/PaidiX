import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

class KycSuccessDialog extends StatelessWidget {
  const KycSuccessDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const KycSuccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.card,
      elevation: 20,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.radiusXl,
        side: BorderSide(color: colors.border, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Checkmark
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.emerald.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.emerald.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.emerald.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: colors.emerald,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Account Setup Complete!',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your profile details, auto-aligned CNIC documents, biometric photo, and Pakistani bank account have been securely received.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Verification status chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildChip('CNIC Auto-Aligned', colors),
                  _buildChip('Glare Reduced', colors),
                  _buildChip('Contrast Enhanced', colors),
                  _buildChip('1-LINK Connected', colors),
                ],
              ),
              const SizedBox(height: 28),

              // Go to Dashboard Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Go to Dashboard',
                  icon: const Icon(Icons.dashboard_rounded, size: 16),
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/app/dashboard');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, PaidiXColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.brand800.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.emerald.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 12,
            color: colors.emerald,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
