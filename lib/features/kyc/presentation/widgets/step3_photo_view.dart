/// Defines step3 photo view in the kyc feature's presentation layer.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../data/kyc_image_processor.dart';
import '../../domain/kyc_models.dart';
import 'kyc_file_picker_tile.dart';
import 'kyc_media_access.dart';

class Step3PhotoView extends StatefulWidget {
  final PhotoDocInfo photoInfo;
  final ValueChanged<PhotoDocInfo> onChanged;
  final VoidCallback onNextStep;
  final VoidCallback onBack;

  const Step3PhotoView({
    super.key,
    required this.photoInfo,
    required this.onChanged,
    required this.onNextStep,
    required this.onBack,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<Step3PhotoView> createState() => _Step3PhotoViewState();
}

class _Step3PhotoViewState extends State<Step3PhotoView>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  final _processor = const KycImageProcessor();
  bool _isProcessing = false;
  bool _isPickingImage = false;
  bool _isCheckingLostData = false;
  double _processingProgress = 0.0;
  String _processingStage = '';

  static bool _lastPickWasCamera = false;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLostData();
  }

  /// Re-syncs lost images and schedules a fresh frame on returning from external camera/gallery.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLostData();
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Restores photo if the Android OS destroyed and recreated MainActivity
  /// while taking camera selfie or selecting photo from gallery.
  Future<void> _checkLostData() async {
    if (kIsWeb ||
        !Platform.isAndroid ||
        _isPickingImage ||
        _isCheckingLostData) {
      return;
    }
    _isCheckingLostData = true;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      final file = response.file;
      if (file != null) {
        await _applyPickedPhoto(file, isCamera: _lastPickWasCamera);
      }
    } catch (e) {
      debugPrint('retrieveLostData error: $e');
    } finally {
      _isCheckingLostData = false;
    }
  }

  /// Reads the selected selfie, records its source, and updates the KYC preview.
  Future<void> _applyPickedPhoto(XFile xFile, {required bool isCamera}) async {
    try {
      final bytes = await xFile.readAsBytes();

      // Reject undecodable files (e.g. HEIC/HEIF on some devices) up-front
      // instead of letting them blank the screen later in Image.memory.
      if (!await KycMediaAccess.isDecodable(bytes)) {
        if (mounted) {
          PaidiXToast.showError(
            context,
            'This image format is not supported. Please choose a JPEG or PNG photo.',
          );
        }
        return;
      }
      if (!mounted) return;

      final fileName = xFile.name.isNotEmpty
          ? xFile.name
          : (isCamera ? 'selfie_camera.jpg' : 'selfie_gallery.jpg');

      widget.onChanged(
        widget.photoInfo.copyWith(
          fileName: fileName,
          filePath: xFile.path,
          bytes: bytes,
          isCameraCapture: isCamera,
          isEnhanced: false,
        ),
      );
    } catch (e) {
      debugPrint('Failed to apply picked photo: $e');
      if (mounted) {
        PaidiXToast.showError(context, 'Error processing photo: $e');
      }
    }
  }

  /// Directly requests physical phone camera permission from Android OS
  /// and opens native camera to capture live biometric selfie photo.
  Future<void> _captureWithCamera() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    HapticFeedback.mediumImpact();
    _lastPickWasCamera = true;

    try {
      final hasPerm = await PermissionHelper.requestCameraPermission(context);
      if (!hasPerm || !mounted) return;

      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: KycMediaAccess.maxDimension,
        maxHeight: KycMediaAccess.maxDimension,
        imageQuality: KycMediaAccess.jpegQuality,
      );

      if (xFile != null) {
        await _applyPickedPhoto(xFile, isCamera: true);
      }
    } catch (e) {
      debugPrint('Camera capture error: $e');
      if (mounted) {
        PaidiXToast.showError(
          context,
          'Could not capture photo. Please check camera permissions.',
        );
      }
    } finally {
      _isPickingImage = false;
    }
  }

  /// Requests native photo permission when needed, then opens the system
  /// picker. The picker downscales high-resolution photos before Dart reads
  /// them, which bounds memory use on lower-memory devices.
  Future<void> _pickFromGallery() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    HapticFeedback.lightImpact();
    _lastPickWasCamera = false;

    try {
      final canOpenPicker = await KycMediaAccess.ensureGalleryAccess(context);
      if (!canOpenPicker || !mounted) return;

      XFile? xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: KycMediaAccess.maxDimension,
        maxHeight: KycMediaAccess.maxDimension,
        imageQuality: KycMediaAccess.jpegQuality,
      );

      if (xFile == null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        try {
          final lost = await _picker.retrieveLostData();
          if (!lost.isEmpty && lost.file != null) {
            xFile = lost.file;
          }
        } catch (_) {}
      }

      if (xFile != null) {
        await _applyPickedPhoto(xFile, isCamera: false);
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      if (mounted) {
        PaidiXToast.showError(
          context,
          'Could not select photo from gallery. Please check permissions.',
        );
      }
    } finally {
      _isPickingImage = false;
    }
  }

  /// Runs the selfie enhancement step and advances after a successful result.
  Future<void> _enhanceAndContinue() async {
    HapticFeedback.mediumImpact();

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStage = 'Verifying portrait framing...';
    });

    final res = await _processor.enhanceDocument(
      rawBytes: widget.photoInfo.bytes,
      fileName: widget.photoInfo.fileName,
      isSelfie: true,
      onProgress: (prog, msg) {
        if (mounted) {
          setState(() {
            _processingProgress = prog;
            _processingStage = msg;
          });
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    widget.onChanged(
      widget.photoInfo.copyWith(
        isEnhanced: true,
        enhancedBytes: res.processedBytes,
      ),
    );
  }

  /// Clears the current selfie so the user can take or choose another image.
  void _retakeOrChooseDifferent() {
    HapticFeedback.selectionClick();
    widget.onChanged(
      widget.photoInfo.copyWith(
        isEnhanced: false,
      ),
    );
  }

  /// Fullscreen interactive inspection viewer with pinch-to-zoom and pan
  void _showFullScreenInspection() {
    HapticFeedback.lightImpact();
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.cardDark,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderFocused, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            size: 18,
                            color: colors.aqua,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Selfie Biometric Inspection',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: colors.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Regulatory biometric compliance note
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: colors.aqua,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Biometric Verification • 256-bit Encrypted Vault',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Interactive Zoom & Pan View
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: _buildAvatarFullImage(colors),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Helper note
                Center(
                  child: Text(
                    'Pinch to zoom or drag to inspect facial biometric details.',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Close / Done button
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    text: 'Close Preview',
                    icon: const Icon(Icons.check_rounded, size: 16),
                    variant: AppButtonVariant.primary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final isEnhanced = widget.photoInfo.isEnhanced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'STEP 3 OF 4',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload your photo.',
          style: TextStyle(
            fontFamily: AppTheme.activeFontFamily,
            color: colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A clear photo of you holding your CNIC. We use this to confirm identity and as your profile picture.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 24),

        // Main Card Container
        Container(
          padding: EdgeInsets.all(screenWidth < 400 ? 16 : 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(color: colors.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isProcessing) ...[
                _buildProcessingIndicator(colors),
              ] else if (isEnhanced) ...[
                // Enhanced Preview State (Matches Screenshot media_1793301028005_644a6942.png)
                _buildEnhancedPreviewState(colors),
              ] else ...[
                // Upload Form State (Matches Screenshot media_1793301028039_54794cb1.png)
                _buildUploadFormState(colors),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Under Card: Back Link
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onBack,
            borderRadius: AppSpacing.radiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the processing indicator section of this interface.
  Widget _buildProcessingIndicator(PaidiXColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: _processingProgress > 0 ? _processingProgress : null,
                strokeWidth: 3.5,
                color: colors.aqua,
                backgroundColor: colors.border,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Processing Biometric Photo...',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _processingStage,
              style: TextStyle(
                color: colors.aqua,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.brand800.withValues(alpha: 0.12),
                borderRadius: AppSpacing.radiusMd,
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Format Verification • Lighting Balance • Quality Check',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the upload form state section of this interface.
  Widget _buildUploadFormState(PaidiXColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Photo Capture with Face Detection box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.inputBackground,
            borderRadius: AppSpacing.radiusLg,
            border: Border.all(
              color: widget.photoInfo.isCameraCapture
                  ? colors.emerald
                  : colors.border.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.aqua.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.aqua.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.face_rounded,
                  color: colors.aqua,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Live Photo Capture with Face Detection',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hold your phone at eye level with your CNIC visible.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: widget.photoInfo.isCameraCapture
                    ? 'Retake / Capture Photo with Camera'
                    : 'Capture Photo with Camera',
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                variant: AppButtonVariant.primary,
                onPressed: _captureWithCamera,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Divider Row: OR CHOOSE EXISTING PHOTO FILE
        Row(
          children: [
            Expanded(
                child: Divider(color: colors.border.withValues(alpha: 0.6))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR CHOOSE EXISTING PHOTO FILE',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
                child: Divider(color: colors.border.withValues(alpha: 0.6))),
          ],
        ),
        const SizedBox(height: 20),

        // File picker tile with bounce animation & ripple
        KycFilePickerTile(
          label: 'SELFIE PHOTO WITH CNIC',
          fileName: widget.photoInfo.fileName,
          hasFile: widget.photoInfo.fileName != null,
          helperText: 'PNG / JPEG up to 10MB',
          onBrowse: _pickFromGallery,
        ),
        const SizedBox(height: 20),

        // Photo Guidelines Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.brand800.withValues(alpha: 0.08),
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: colors.aqua,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Photo Guidelines',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildGuidelineBullet(
                'Make sure your face is clearly visible, well-lit, and in focus.',
                colors,
              ),
              const SizedBox(height: 4),
              _buildGuidelineBullet(
                'Hold your CNIC next to your face without obscuring features.',
                colors,
              ),
              const SizedBox(height: 4),
              _buildGuidelineBullet(
                'This photo will also be used as your PaidiX profile avatar.',
                colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amber Notice Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.gold.withValues(alpha: 0.08),
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: colors.gold.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: colors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: colors.gold,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Biometric Photo Standard: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            'Ensure your face is centered, evenly lit, and clearly visible without hats or sunglasses.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Button: Continue with spring bounce & ripple
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            text: 'Continue',
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            variant: AppButtonVariant.primary,
            onPressed: (widget.photoInfo.fileName != null)
                ? _enhanceAndContinue
                : null,
          ),
        ),
      ],
    );
  }

  /// Builds the guideline bullet section of this interface.
  Widget _buildGuidelineBullet(String text, PaidiXColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            color: colors.aqua,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the enhanced preview state section of this interface.
  Widget _buildEnhancedPreviewState(PaidiXColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Green Banner (Matches exact screenshot media_1793301028005_644a6942.png)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.emerald.withValues(alpha: 0.12),
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: colors.emerald.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: colors.emerald,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric Photo Preview',
                      style: TextStyle(
                        color: colors.emerald,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your biometric profile photo has been securely processed for identity verification.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Circular Enhanced Avatar Preview with Glowing Emerald Border & Tap-to-Inspect
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _showFullScreenInspection,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.emerald,
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.emerald.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarImage(colors),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3A35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.emerald,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
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
                              'Uploaded',
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Interactive Inspection Pill
              InkWell(
                onTap: _showFullScreenInspection,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.brand800.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.aqua.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.zoom_in_rounded,
                        size: 14,
                        color: colors.aqua,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to inspect photo in detail',
                        style: TextStyle(
                          color: colors.aqua,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bottom Actions: Retake / Choose Different Photo (left) and Next Step -> (right)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              onPressed: _retakeOrChooseDifferent,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                'Retake / Choose Different Photo',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppButton(
              text: 'Next Step',
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              variant: AppButtonVariant.primary,
              onPressed: widget.onNextStep,
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the avatar image section of this interface.
  Widget _buildAvatarImage(PaidiXColorScheme colors) {
    // errorBuilder: an undecodable photo falls back to the avatar placeholder
    // instead of replacing the screen with a blank/grey ErrorWidget.
    if (widget.photoInfo.enhancedBytes != null) {
      return Image.memory(
        widget.photoInfo.enhancedBytes!,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(colors),
      );
    }
    if (widget.photoInfo.bytes != null) {
      return Image.memory(
        widget.photoInfo.bytes!,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(colors),
      );
    }
    if (widget.photoInfo.filePath != null &&
        !kIsWeb &&
        File(widget.photoInfo.filePath!).existsSync()) {
      return Image.file(
        File(widget.photoInfo.filePath!),
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(colors),
      );
    }

    return _buildAvatarPlaceholder(colors);
  }

  Widget _buildAvatarPlaceholder(PaidiXColorScheme colors) {
    // High fidelity synthetic avatar graphic
    return Container(
      color: const Color(0xFF072B2B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_rounded,
              size: 64,
              color: colors.aqua.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 2),
            Text(
              'KYC VERIFIED',
              style: TextStyle(
                fontFamily: AppTheme.activeFontFamily,
                color: colors.emerald,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the avatar full image section of this interface.
  Widget _buildAvatarFullImage(PaidiXColorScheme colors) {
    if (widget.photoInfo.enhancedBytes != null) {
      return Image.memory(
        widget.photoInfo.enhancedBytes!,
        fit: BoxFit.contain,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => _buildAvatarFullPlaceholder(colors),
      );
    }
    if (widget.photoInfo.bytes != null) {
      return Image.memory(
        widget.photoInfo.bytes!,
        fit: BoxFit.contain,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => _buildAvatarFullPlaceholder(colors),
      );
    }
    if (widget.photoInfo.filePath != null &&
        !kIsWeb &&
        File(widget.photoInfo.filePath!).existsSync()) {
      return Image.file(
        File(widget.photoInfo.filePath!),
        fit: BoxFit.contain,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) => _buildAvatarFullPlaceholder(colors),
      );
    }

    return _buildAvatarFullPlaceholder(colors);
  }

  Widget _buildAvatarFullPlaceholder(PaidiXColorScheme colors) {
    return Container(
      color: const Color(0xFF072B2B),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_rounded,
              size: 96,
              color: colors.aqua.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
            Text(
              'KYC BIOMETRIC AVATAR',
              style: TextStyle(
                fontFamily: AppTheme.activeFontFamily,
                color: colors.emerald,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
