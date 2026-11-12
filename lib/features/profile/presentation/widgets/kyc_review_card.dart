/// Defines kyc review card in the profile feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/user_profile.dart';
import 'document_preview_tile.dart';
import 'document_viewer_dialog.dart';

/// Card presenting regulatory KYC verification status and document assets
/// on file (Selfie, CNIC Front, CNIC Back) with interactive inspection.
class KycReviewCard extends StatelessWidget {
  final UserProfile profile;

  const KycReviewCard({super.key, required this.profile});

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Container(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(
              color: colors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Shield Icon + KYC REVIEW + Status Badge
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Shield icon + title
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: colors.aqua,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'KYC REVIEW',
                        style: TextStyle(
                          fontFamily: AppTheme.activeFontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Status Badge matching screenshot ("• Pending Review")
                  _buildStatusPill(colors),
                ],
              ),

              if (profile.kycStatus == KycReviewStatus.rejected &&
                  profile.formattedKycReviewedAt != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    'Last reviewed ${profile.formattedKycReviewedAt}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
              if (profile.hasResubmittedKyc &&
                  profile.formattedKycResubmittedAt != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    'Submitted for review ${profile.formattedKycResubmittedAt}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Document Previews:
              // Row 1: Selfie & CNIC - Front
              Row(
                children: [
                  Expanded(
                    child: DocumentPreviewTile(
                      label: 'SELFIE',
                      isSelfie: true,
                      bytes: profile.selfieBytes,
                      filePath: profile.selfieFilePath,
                      imageUrl: profile.selfieUrl,
                      onTap: () => DocumentViewerDialog.show(
                        context,
                        title: 'Selfie Biometric Photo',
                        subtitle:
                            'Biometric portrait on file with State Bank compliance',
                        bytes: profile.selfieBytes,
                        filePath: profile.selfieFilePath,
                        imageUrl: profile.selfieUrl,
                        isSelfie: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DocumentPreviewTile(
                      label: 'CNIC — FRONT',
                      bytes: profile.cnicFrontBytes,
                      filePath: profile.cnicFrontFilePath,
                      imageUrl: profile.cnicFrontUrl,
                      onTap: () => DocumentViewerDialog.show(
                        context,
                        title: 'CNIC Front Document',
                        subtitle:
                            'National Identity Card Front • NADRA verified',
                        bytes: profile.cnicFrontBytes,
                        filePath: profile.cnicFrontFilePath,
                        imageUrl: profile.cnicFrontUrl,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: CNIC - Back
              Row(
                children: [
                  Expanded(
                    child: DocumentPreviewTile(
                      label: 'CNIC — BACK',
                      bytes: profile.cnicBackBytes,
                      filePath: profile.cnicBackFilePath,
                      imageUrl: profile.cnicBackUrl,
                      onTap: () => DocumentViewerDialog.show(
                        context,
                        title: 'CNIC Back Document',
                        subtitle:
                            'National Identity Card Back • Security barcode',
                        bytes: profile.cnicBackBytes,
                        filePath: profile.cnicBackFilePath,
                        imageUrl: profile.cnicBackUrl,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the status pill section of this interface.
  Widget _buildStatusPill(PaidiXColorScheme colors) {
    final isVerified = profile.kycStatus.isVerified;
    final isRejected = profile.kycStatus.isRejected;
    final isResubmitted = profile.hasResubmittedKyc &&
        profile.kycStatus == KycReviewStatus.pendingReview;
    const rejectedColor = Color(0xFFBE123C);
    const resubmittedColor = Color(0xFF8064D9);
    final pillBg = isVerified
        ? colors.emerald.withValues(alpha: 0.12)
        : isRejected
            ? rejectedColor.withValues(alpha: 0.08)
            : isResubmitted
                ? resubmittedColor.withValues(alpha: 0.08)
                : colors.gold.withValues(alpha: 0.12);
    final pillBorder = isVerified
        ? colors.emerald.withValues(alpha: 0.40)
        : isRejected
            ? rejectedColor.withValues(alpha: 0.30)
            : isResubmitted
                ? resubmittedColor.withValues(alpha: 0.30)
                : colors.gold.withValues(alpha: 0.40);
    final dotColor = isVerified
        ? colors.emerald
        : isRejected
            ? rejectedColor
            : isResubmitted
                ? resubmittedColor
                : colors.gold;
    final textColor = dotColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pillBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isRejected
                ? 'Rejected'
                : isResubmitted
                    ? 'Resubmitted'
                    : profile.kycStatus.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
