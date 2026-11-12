/// Defines status badge in the application core utilities and reusable widgets.

import 'package:material_ui/material_ui.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum PaymentStatusType {
  submitted,
  underReview,
  pendingReview,
  verified,
  pkrSent,
  awaitingPkr,
  completed,
  onHold,
  rejected,
}

class StatusBadge extends StatelessWidget {
  final PaymentStatusType status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Color bg;
    Color fg;
    Color dot;
    String label;

    switch (status) {
      case PaymentStatusType.submitted:
        bg = const Color(0xFF0F2D3D);
        fg = const Color(0xFF38BDF8);
        dot = const Color(0xFF38BDF8);
        label = customLabel ?? 'Submitted';
        break;
      case PaymentStatusType.underReview:
      case PaymentStatusType.pendingReview:
        bg = colors.statusPendingBg;
        fg = colors.statusPendingText;
        dot = colors.statusPendingDot;
        label = customLabel ??
            (status == PaymentStatusType.pendingReview
                ? 'Pending Review'
                : 'Under Review');
        break;
      case PaymentStatusType.verified:
        bg = const Color(0xFF0B3330);
        fg = colors.aqua;
        dot = colors.aqua;
        label = customLabel ?? 'Verified';
        break;
      case PaymentStatusType.pkrSent:
      case PaymentStatusType.awaitingPkr:
        bg = colors.statusAwaitingBg;
        fg = colors.statusAwaitingText;
        dot = colors.statusAwaitingDot;
        label = customLabel ??
            (status == PaymentStatusType.awaitingPkr
                ? 'Awaiting PKR'
                : 'PKR Sent');
        break;
      case PaymentStatusType.completed:
        bg = colors.statusCompletedBg;
        fg = colors.statusCompletedText;
        dot = colors.statusCompletedDot;
        label = customLabel ?? 'Completed';
        break;
      case PaymentStatusType.onHold:
        bg = const Color(0xFF3B2410);
        fg = const Color(0xFFFB923C);
        dot = const Color(0xFFFB923C);
        label = customLabel ?? 'On Hold';
        break;
      case PaymentStatusType.rejected:
        bg = colors.statusErrorBg;
        fg = colors.statusErrorText;
        dot = colors.statusErrorDot;
        label = customLabel ?? 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusPill,
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.badgeText.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
