/// Defines step2 identity view in the kyc feature's presentation layer.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/cnic_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../data/kyc_image_processor.dart';
import '../../domain/kyc_models.dart';
import 'kyc_file_picker_tile.dart';
import 'kyc_media_access.dart';

class Step2IdentityView extends StatefulWidget {
  final IdentityDocInfo identityInfo;
  final ValueChanged<IdentityDocInfo> onChanged;
  final VoidCallback onNextStep;
  final VoidCallback onBack;

  const Step2IdentityView({
    super.key,
    required this.identityInfo,
    required this.onChanged,
    required this.onNextStep,
    required this.onBack,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<Step2IdentityView> createState() => _Step2IdentityViewState();
}

class _Step2IdentityViewState extends State<Step2IdentityView>
    with WidgetsBindingObserver {
  late final TextEditingController _cnicController;
  final _picker = ImagePicker();
  final _processor = const KycImageProcessor();

  bool _isProcessing = false;
  bool _isPickingImage = false;
  bool _isCheckingLostData = false;
  double _processingProgress = 0.0;
  String _processingStage = '';

  CnicStatus _cnicStatus = CnicStatus.empty;
  Timer? _debounceTimer;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialCnic = widget.identityInfo.cnicNumber;
    _cnicController = TextEditingController(text: initialCnic);
    if (initialCnic.isNotEmpty) {
      _validateCnicRealtime(initialCnic, debounce: false);
    }
    _checkLostData();
  }

  /// Restores image if the Android OS destroyed and recreated MainActivity
  /// while the user was interacting with external Gallery app.
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
      if (response.exception != null) {
        debugPrint('retrieveLostData exception: ${response.exception}');
      }
      final file = response.file;
      if (file != null) {
        final pending = UserProfileRepository.instance.pendingPickSide;
        final isFront = pending != 'cnic_back';
        await _applyPickedImage(file, isFront);
        await UserProfileRepository.instance.setPendingPickSide(null);
      }
    } catch (e) {
      debugPrint('retrieveLostData error: $e');
    } finally {
      _isCheckingLostData = false;
    }
  }

  /// Re-syncs lost images and schedules a fresh frame on returning from external gallery.
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
    _debounceTimer?.cancel();
    _cnicController.dispose();
    super.dispose();
  }

  /// Stores the edited CNIC value and restarts its format/availability checks.
  void _onCnicChanged(String val) {
    widget.onChanged(
      widget.identityInfo.copyWith(cnicNumber: val.trim()),
    );
    _validateCnicRealtime(val, debounce: true);
  }

  /// Checks CNIC completeness, format, and simulated registry availability.
  void _validateCnicRealtime(String val, {bool debounce = true}) {
    _debounceTimer?.cancel();
    final clean = CnicValidator.clean(val);

    if (clean.isEmpty) {
      setState(() => _cnicStatus = CnicStatus.empty);
      return;
    }

    if (clean.length < 13) {
      setState(() => _cnicStatus = CnicStatus.incomplete);
      return;
    }

    setState(() => _cnicStatus = CnicStatus.checking);

    final activeEmail = UserProfileRepository.instance.profile.email;

    if (debounce) {
      _debounceTimer = Timer(const Duration(milliseconds: 320), () async {
        final status = await CnicValidator.checkAvailability(
          val,
          excludeEmail: activeEmail,
        );
        if (mounted) {
          setState(() => _cnicStatus = status);
          if (status == CnicStatus.available) {
            HapticFeedback.selectionClick();
          }
        }
      });
    } else {
      CnicValidator.checkAvailability(
        val,
        excludeEmail: activeEmail,
      ).then((status) {
        if (mounted) {
          setState(() => _cnicStatus = status);
        }
      });
    }
  }

  /// Stores a selected CNIC-side image and refreshes its document preview.
  Future<void> _applyPickedImage(XFile xFile, bool isFront) async {
    try {
      final sourceBytes = await xFile.readAsBytes();
      final bytes = await KycMediaAccess.validateImage(sourceBytes);
      // The view can be disposed while the gallery / file read was in flight
      // (Android recreating the activity). Don't push state into a dead tree.
      if (!mounted) return;

      final fileName = xFile.name.isNotEmpty
          ? xFile.name
          : (isFront ? 'cnic_front.jpg' : 'cnic_back.jpg');

      if (isFront) {
        widget.onChanged(
          widget.identityInfo.copyWith(
            frontFileName: fileName,
            frontFilePath: xFile.path,
            frontBytes: bytes,
            isEnhanced: false,
            clearEnhancedFrontBytes: true,
          ),
        );
      } else {
        widget.onChanged(
          widget.identityInfo.copyWith(
            backFileName: fileName,
            backFilePath: xFile.path,
            backBytes: bytes,
            isEnhanced: false,
            clearEnhancedBackBytes: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying picked image bytes: $e');
      if (mounted) {
        PaidiXToast.showError(context, 'Error processing image: $e');
      }
    }
  }

  /// Requests native photo permission when needed, then opens the system
  /// picker. The picker downscales high-resolution photos before Dart reads
  /// them, which bounds memory use on lower-memory devices.
  Future<void> _pickImage(bool isFront) async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    HapticFeedback.lightImpact();
    // Permission request is handled by the OS; scoped picker access still
    // works if the user declines broad photo-library access.
    try {
      final canOpenPicker = await KycMediaAccess.ensureGalleryAccess(context);
      if (!canOpenPicker || !mounted) return;

      await UserProfileRepository.instance.setPendingPickSide(
        isFront ? 'cnic_front' : 'cnic_back',
      );
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
        await _applyPickedImage(xFile, isFront);
      }
    } catch (e) {
      debugPrint('pickImage error: $e');
      if (mounted) {
        PaidiXToast.showError(
          context,
          'Could not load photo from gallery. Please check permissions.',
        );
      }
    } finally {
      _isPickingImage = false;
      await UserProfileRepository.instance.setPendingPickSide(null);
    }
  }

  /// Enhances both CNIC images and advances once the identity step is complete.
  Future<void> _enhanceAndContinue() async {
    HapticFeedback.mediumImpact();

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStage = 'Preparing documents for verification...';
    });

    final frontRes = await _processor.enhanceDocument(
      rawBytes: widget.identityInfo.frontBytes,
      fileName: widget.identityInfo.frontFileName,
      isSelfie: false,
      onProgress: (prog, msg) {
        if (mounted) {
          setState(() {
            _processingProgress = prog * 0.5;
            _processingStage = 'Front: $msg';
          });
        }
      },
    );

    final backRes = await _processor.enhanceDocument(
      rawBytes: widget.identityInfo.backBytes,
      fileName: widget.identityInfo.backFileName,
      isSelfie: false,
      onProgress: (prog, msg) {
        if (mounted) {
          setState(() {
            _processingProgress = 0.5 + (prog * 0.5);
            _processingStage = 'Back: $msg';
          });
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    widget.onChanged(
      widget.identityInfo.copyWith(
        cnicNumber: _cnicController.text.trim(),
        isEnhanced: true,
        enhancedFrontBytes: frontRes.processedBytes,
        enhancedBackBytes: backRes.processedBytes,
      ),
    );
  }

  /// Clears the selected CNIC images so the user can replace them.
  void _reuploadDifferentImages() {
    HapticFeedback.selectionClick();
    widget.onChanged(
      widget.identityInfo.copyWith(
        isEnhanced: false,
      ),
    );
  }

  /// Opens the selected identity image for full-screen inspection.
  void _showFullScreenInspection({
    required String title,
    required Uint8List? bytes,
    required String? filePath,
    required bool isBack,
  }) {
    HapticFeedback.lightImpact();
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.cardDark,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusXl,
          side: BorderSide(color: colors.borderFocused, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: colors.textSecondary, size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Regulatory compliance note
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: colors.aqua,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'State Bank KYC Compliance • Encrypted Vault',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Interactive Zoom & Inspection Viewport
                ClipRRect(
                  borderRadius: AppSpacing.radiusLg,
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    color: const Color(0xFF021B19),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Center(
                        child: _buildDocumentGraphic(
                          bytes,
                          filePath,
                          isBack,
                          colors,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Pinch to zoom or drag to inspect document details.',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

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
    final isWide = screenWidth > 640;

    final isEnhanced = widget.identityInfo.isEnhanced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'STEP 2 OF 4',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Verify your identity.',
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
          'Upload clear photos of both sides of your CNIC.',
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
                _buildEnhancedPreviewState(colors, isWide),
              ] else ...[
                _buildUploadFormState(colors, isWide),
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
              'Processing Identity Documents...',
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
                'Boundary Detection • Lighting Balance • Format Verification',
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
  Widget _buildUploadFormState(PaidiXColorScheme colors, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CNIC NUMBER label
        Text(
          'CNIC NUMBER',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),

        // CNIC Text Field with Auto-Hyphenation Formatter
        Container(
          decoration: BoxDecoration(
            color: colors.inputBackground,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: _cnicStatus == CnicStatus.invalidFormat ||
                      _cnicStatus == CnicStatus.alreadyRegistered
                  ? colors.ruby
                  : _cnicStatus == CnicStatus.available
                      ? colors.emerald.withValues(alpha: 0.6)
                      : colors.border.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: _cnicController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
              CnicInputFormatter(),
            ],
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '42101-1234567-1',
              hintStyle: TextStyle(
                color: colors.textMuted.withValues(alpha: 0.5),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
                letterSpacing: 1.0,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: _onCnicChanged,
          ),
        ),
        const SizedBox(height: 6),

        // Intelligent Real-Time Synced Status Widget
        _buildRealtimeCnicStatus(colors),
        const SizedBox(height: 18),

        // Document Upload Row (Front and Back)
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KycFilePickerTile(
                  label: 'CNIC — FRONT',
                  fileName: widget.identityInfo.frontFileName,
                  hasFile: widget.identityInfo.frontFileName != null,
                  onBrowse: () => _pickImage(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: KycFilePickerTile(
                  label: 'CNIC — BACK',
                  fileName: widget.identityInfo.backFileName,
                  hasFile: widget.identityInfo.backFileName != null,
                  onBrowse: () => _pickImage(false),
                ),
              ),
            ],
          )
        else ...[
          KycFilePickerTile(
            label: 'CNIC — FRONT',
            fileName: widget.identityInfo.frontFileName,
            hasFile: widget.identityInfo.frontFileName != null,
            onBrowse: () => _pickImage(true),
          ),
          const SizedBox(height: 16),
          KycFilePickerTile(
            label: 'CNIC — BACK',
            fileName: widget.identityInfo.backFileName,
            hasFile: widget.identityInfo.backFileName != null,
            onBrowse: () => _pickImage(false),
          ),
        ],
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
                        text: 'State Bank KYC Requirement: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            'Ensure all four corners of your CNIC are clearly visible and text is sharp and legible without glare.',
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
            onPressed: (_cnicStatus == CnicStatus.available &&
                    widget.identityInfo.frontFileName != null &&
                    widget.identityInfo.backFileName != null)
                ? _enhanceAndContinue
                : null,
          ),
        ),
      ],
    );
  }

  /// Real-time status display with animations for "Available" / checking / error
  Widget _buildRealtimeCnicStatus(PaidiXColorScheme colors) {
    switch (_cnicStatus) {
      case CnicStatus.empty:
        return const SizedBox.shrink();

      case CnicStatus.incomplete:
        final digits = CnicValidator.clean(_cnicController.text);
        return Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: colors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Enter complete 13-digit CNIC number (${digits.length}/13)',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );

      case CnicStatus.checking:
        return Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.aqua,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Checking CNIC registration status...',
              style: TextStyle(
                fontFamily: AppTheme.activeFontFamily,
                color: colors.aqua,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case CnicStatus.available:
        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 13,
                color: colors.emerald,
              ),
              const SizedBox(width: 4),
              Text(
                'Available',
                style: TextStyle(
                  fontFamily: AppTheme.activeFontFamily,
                  color: colors.emerald,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Unique CNIC • Unregistered',
                  style: TextStyle(
                    fontFamily: AppTheme.activeFontFamily,
                    color: colors.emerald,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case CnicStatus.alreadyRegistered:
        return Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 13,
              color: colors.ruby,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'This CNIC is already registered to an existing account. Please sign in.',
                style: TextStyle(
                  fontFamily: AppTheme.activeFontFamily,
                  color: colors.ruby,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case CnicStatus.invalidFormat:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 13,
              color: colors.ruby,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Invalid province/division code (must start with 1-8)',
                style: TextStyle(
                  color: colors.ruby,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
    }
  }

  /// Builds the enhanced preview state section of this interface.
  Widget _buildEnhancedPreviewState(PaidiXColorScheme colors, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Green Banner
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
                      'CNIC Document Preview',
                      style: TextStyle(
                        color: colors.emerald,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your CNIC document images have been securely processed and encrypted. Tap any image to inspect details.',
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
        const SizedBox(height: 20),

        // Two Cards Side-by-Side (or stacked on mobile)
        if (isWide)
          Row(
            children: [
              Expanded(
                child: _buildDocCard(
                  colors: colors,
                  title: 'CNIC — Front',
                  bytes: widget.identityInfo.enhancedFrontBytes ??
                      widget.identityInfo.frontBytes,
                  filePath: widget.identityInfo.frontFilePath,
                  isBack: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDocCard(
                  colors: colors,
                  title: 'CNIC — Back',
                  bytes: widget.identityInfo.enhancedBackBytes ??
                      widget.identityInfo.backBytes,
                  filePath: widget.identityInfo.backFilePath,
                  isBack: true,
                ),
              ),
            ],
          )
        else ...[
          _buildDocCard(
            colors: colors,
            title: 'CNIC — Front',
            bytes: widget.identityInfo.enhancedFrontBytes ??
                widget.identityInfo.frontBytes,
            filePath: widget.identityInfo.frontFilePath,
            isBack: false,
          ),
          const SizedBox(height: 16),
          _buildDocCard(
            colors: colors,
            title: 'CNIC — Back',
            bytes: widget.identityInfo.enhancedBackBytes ??
                widget.identityInfo.backBytes,
            filePath: widget.identityInfo.backFilePath,
            isBack: true,
          ),
        ],
        const SizedBox(height: 24),

        // Bottom Actions: Re-upload Different Images and Next Step
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              onPressed: _reuploadDifferentImages,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                'Re-upload Different Images',
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

  /// Builds the doc card section of this interface.
  Widget _buildDocCard({
    required PaidiXColorScheme colors,
    required String title,
    required Uint8List? bytes,
    required String? filePath,
    required bool isBack,
  }) {
    return InkWell(
      onTap: () => _showFullScreenInspection(
        title: title,
        bytes: bytes,
        filePath: filePath,
        isBack: isBack,
      ),
      borderRadius: AppSpacing.radiusLg,
      child: Container(
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: AppSpacing.radiusLg,
          border: Border.all(
              color: colors.border.withValues(alpha: 0.8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and ✓ Enhanced badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.emerald.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: colors.emerald,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Uploaded',
                          style: TextStyle(
                            color: colors.emerald,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Image preview container with zoom badge overlay
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF021B19),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    child:
                        _buildDocumentGraphic(bytes, filePath, isBack, colors),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.zoom_in_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the document graphic section of this interface.
  Widget _buildDocumentGraphic(
    Uint8List? bytes,
    String? filePath,
    bool isBack,
    PaidiXColorScheme colors,
  ) {
    // errorBuilder: if bytes/file can't be decoded (corrupt file, unsupported
    // codec, the 64-byte stub from a failed pick) fall back to the CNIC
    // placeholder instead of letting Flutter replace the screen with a
    // blank/grey ErrorWidget in release builds.
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 1080,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildCnicPlaceholder(isBack, colors),
      );
    }
    if (filePath != null && !kIsWeb && File(filePath).existsSync()) {
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 1080,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildCnicPlaceholder(isBack, colors),
      );
    }

    return _buildCnicPlaceholder(isBack, colors);
  }

  /// High fidelity synthetic CNIC illustration shown when no decodable image
  /// is available.
  Widget _buildCnicPlaceholder(bool isBack, PaidiXColorScheme colors) {
    final displayCnic = _cnicController.text.isNotEmpty
        ? CnicValidator.format(_cnicController.text)
        : '42101-1234567-1';

    // High fidelity synthetic CNIC illustration with real user CNIC
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF072B2B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF145753),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.emerald.withValues(alpha: 0.2),
                    border: Border.all(color: colors.emerald, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'PK',
                      style: TextStyle(
                        fontFamily: AppTheme.activeFontFamily,
                        color: colors.emerald,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOVERNMENT OF PAKISTAN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      isBack
                          ? 'NATIONAL IDENTITY CARD (BACK)'
                          : 'NATIONAL IDENTITY CARD (FRONT)',
                      style: TextStyle(
                        color: colors.aqua,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayCnic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'STATE BANK COMPLIANT',
                      style: TextStyle(
                        color: colors.emerald,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isBack ? Icons.qr_code_2_rounded : Icons.fingerprint_rounded,
                  size: 26,
                  color: colors.aqua.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
