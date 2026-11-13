/// Centralized permission and image-memory utility for camera and photo storage access.
///
/// Handles Android 13+ (READ_MEDIA_IMAGES / Permission.photos), Android <= 12
/// (READ_EXTERNAL_STORAGE / Permission.storage), and iOS photo library permissions.
/// Safely downscales large camera bitmaps to avoid native ART/Dalvik OOM crashes
/// on high-resolution camera devices (e.g. Huawei EMUI, Samsung, Xiaomi).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../features/kyc/data/kyc_image_validation.dart';
import '../../features/kyc/presentation/widgets/kyc_permission_dialog.dart';
import '../widgets/app_button.dart';

class PermissionHelper {
  const PermissionHelper._();

  static bool _hasPromptedCameraInSession = false;

  /// Resets permission session tracking (useful for test suites)
  @visibleForTesting
  static void resetSessionPrompts() {
    _hasPromptedCameraInSession = false;
  }

  static bool get _isTestEnv {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Safely requests photo gallery / storage permission across all Android and iOS versions.
  /// Opens the platform picker directly without an app-specific gallery rationale dialog.
  static Future<bool> requestStorageOrPhotosPermission(
    BuildContext context,
  ) async {
    if (kIsWeb || _isTestEnv) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      // Request Android OS runtime permissions (photos + storage).
      // The system image picker remains the fallback when broad access is declined.
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.photos,
          Permission.storage,
        ].request();

        final photosStatus = statuses[Permission.photos];
        final storageStatus = statuses[Permission.storage];

        final isGranted =
            (photosStatus?.isGranted ?? false) ||
            (photosStatus?.isLimited ?? false) ||
            (storageStatus?.isGranted ?? false) ||
            (storageStatus?.isLimited ?? false);

        if (isGranted) return true;

        final isPermanentlyDenied =
            (photosStatus?.isPermanentlyDenied ?? false) &&
            (storageStatus?.isPermanentlyDenied ?? false);

        if (isPermanentlyDenied && context.mounted) {
          _showSettingsDialog(
            context,
            title: 'Photos & Storage Permission',
            message: 'PaidiX requires access to your device storage or photos to select your CNIC and documents. Please enable access in App Settings.',
          );
          return false;
        }

        // Allow system document picker fallback
        return true;
      } else if (Platform.isIOS) {
        final status = await Permission.photos.status;
        if (status.isGranted || status.isLimited) return true;

        if (status.isPermanentlyDenied) {
          if (context.mounted) {
            _showSettingsDialog(
              context,
              title: 'Photo Library Access',
              message: 'PaidiX requires access to your photo library to select documents. Please enable access in Settings.',
            );
          }
          return false;
        }

        final req = await Permission.photos.request();
        return req.isGranted || req.isLimited;
      }
    } catch (e) {
      debugPrint('[PermissionHelper] Photos check warning: $e');
    }
    return true;
  }

  /// Safely requests physical phone camera permission.
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb || _isTestEnv) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      if (!_hasPromptedCameraInSession) {
        if (context.mounted) {
          final accepted = await KycPermissionDialog.show(
            context,
            isCamera: true,
            onGranted: () {},
          );
          if (accepted != true) return false;
          _hasPromptedCameraInSession = true;
        }
      }

      final camStatus = await Permission.camera.request();
      if (camStatus.isGranted || camStatus.isLimited) return true;

      if (camStatus.isPermanentlyDenied && context.mounted) {
        _showSettingsDialog(
          context,
          title: 'Camera Access Required',
          message: 'PaidiX requires camera access to capture your selfie and verification documents. Please enable camera in App Settings.',
        );
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('[PermissionHelper] Camera check warning: $e');
    }
    return true;
  }

  /// Downscales raw image bytes safely using Flutter Skia engine.
  /// Prevents GPU out-of-memory spikes and blank screen rendering on Huawei EMUI.
  static Future<Uint8List> safeDownscaleBytes(
    Uint8List rawBytes, {
    int maxDimension = 1024,
  }) async {
    if (rawBytes.isEmpty) return rawBytes;

    ui.Codec? codec;
    ui.Image? image;
    try {
      // Bound the decoded frame before Skia allocates pixels. Huawei Gallery
      // can return a low-byte-size but very high-resolution CNIC image, so a
      // compressed-file-size shortcut still leaves a large native bitmap.
      codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
        allowUpscaling: false,
      );
      final frameInfo = await codec.getNextFrame();
      image = frameInfo.image;
      if (image.width <= maxDimension && image.height <= maxDimension) {
        return rawBytes;
      }
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final scaled = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        if (scaled.lengthInBytes <= KycImageValidation.maxFileSizeBytes ||
            rawBytes.lengthInBytes > KycImageValidation.maxFileSizeBytes) {
          return scaled;
        }
      }
    } catch (e) {
      debugPrint('[PermissionHelper] Downscale fallback: $e');
    } finally {
      image?.dispose();
      codec?.dispose();
    }
    return rawBytes;
  }

  /// Displays settings dialog when permission is permanently denied.
  static void _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.card,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusXl,
          side: BorderSide(color: colors.border, width: 1.2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.gold.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.settings_outlined,
                      color: colors.gold,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      text: 'Open Settings',
                      variant: AppButtonVariant.primary,
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        openAppSettings();
                      },
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
