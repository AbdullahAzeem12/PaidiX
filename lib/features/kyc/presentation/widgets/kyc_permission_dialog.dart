/// Defines kyc permission dialog in the kyc feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

class KycPermissionDialog extends StatelessWidget {
  final bool isCamera;
  final VoidCallback onGranted;

  const KycPermissionDialog({
    super.key,
    required this.isCamera,
    required this.onGranted,
  });

  /// Shows the permission rationale and returns whether the user accepted it.
  static Future<bool?> show(
    BuildContext context, {
    required bool isCamera,
    required VoidCallback onGranted,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => KycPermissionDialog(
        isCamera: isCamera,
        onGranted: () {
          Navigator.of(ctx).pop(true);
          onGranted();
        },
      ),
    );
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.card,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.radiusXl,
        side: BorderSide(color: colors.border, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 380 ? 16 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Icon Header with glowing circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.aqua.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.aqua.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isCamera
                        ? Icons.camera_alt_rounded
                        : Icons.photo_library_rounded,
                    color: colors.aqua,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                isCamera
                    ? 'Camera Access Required'
                    : 'Photo Gallery Access Required',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                isCamera
                    ? 'PaidiX requires access to your physical phone camera to capture high-definition live photos with real-time face detection for identity verification.'
                    : 'PaidiX requires access to your physical phone photo gallery to upload clear, high-resolution photos of your CNIC front and back.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),

              // Security & Privacy Pill Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.brand800.withValues(alpha: 0.08),
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: colors.emerald,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your biometric and identity documents are encrypted end-to-end with 256-bit AES encryption and used solely for State Bank regulatory KYC compliance.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.radiusMd,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppButton(
                    text: 'Grant Permission',
                    variant: AppButtonVariant.primary,
                    icon: Icon(
                      isCamera
                          ? Icons.camera_alt_outlined
                          : Icons.folder_open_rounded,
                      size: 16,
                      color: colors.primaryButtonText,
                    ),
                    onPressed: onGranted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
