/// Defines empty state in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'app_button.dart';

class EmptyStateView extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? icon;

  const EmptyStateView({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
    this.icon,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon ??
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.cardDark,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(color: colors.border, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.description_outlined,
                  color: colors.aqua,
                  size: 26,
                ),
              ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 20),
            AppButton(
              text: actionText!,
              icon: Icon(Icons.add_circle_outline_rounded,
                  size: 18, color: colors.primaryButtonText),
              onPressed: onAction,
              variant: AppButtonVariant.primary,
            ),
          ],
        ],
      ),
    );
  }
}
