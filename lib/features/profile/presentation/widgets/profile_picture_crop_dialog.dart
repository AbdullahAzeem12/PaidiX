import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/spongy_tap.dart';

class _FilterOption {
  final String name;
  final String label;
  final ColorFilter? colorFilter;

  const _FilterOption({
    required this.name,
    required this.label,
    this.colorFilter,
  });
}

/// Professional Real-World Interactive Cropper & Portrait Filter Studio
/// designed specifically for the Profile Picture section.
///
/// Features:
/// - True 1:1 Aspect Ratio Rendering: Completely eliminates squishing, squeezing or distortion.
/// - Interactive Pan & Drag: Freely position and centralize face/subject.
/// - Interactive Zoom: Pinch-to-zoom and precision slider (1.0x to 3.5x).
/// - 90-Degree Rotation: Quick alignment for landscape or oriented captures.
/// - Rule-of-Thirds Grid: Subtle alignment crosshairs for perfect eye-line centering.
/// - 5 Authentic Portrait Filters: Original, Studio Vibrant, Crisp Clarity, Warm Gold, Monochrome.
/// - High-Resolution Output: Renders pristine 512x512 PNG bytes.
class ProfilePictureCropDialog extends StatefulWidget {
  final Uint8List rawBytes;

  const ProfilePictureCropDialog({
    super.key,
    required this.rawBytes,
  });

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List rawBytes,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.85 : 0.70,
      ),
      builder: (ctx) => ProfilePictureCropDialog(rawBytes: rawBytes),
    );
  }

  @override
  State<ProfilePictureCropDialog> createState() => ProfilePictureCropDialogState();
}

class ProfilePictureCropDialogState extends State<ProfilePictureCropDialog> {
  static const double _cropSize = 250.0;

  ui.Image? _decodedImage;
  bool _isLoading = true;
  String? _errorMessage;

  // Transform states
  double _scale = 1.0;
  double _baseScaleOnStart = 1.0;
  Offset _offset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  Offset _startOffset = Offset.zero;
  int _rotationQuarterTurns = 0; // 0, 1, 2, 3 (0°, 90°, 180°, 270°)

  int _selectedFilterIndex = 0;
  bool _isSaving = false;

  static const List<_FilterOption> _filters = [
    _FilterOption(
      name: 'original',
      label: 'Original',
      colorFilter: null,
    ),
    _FilterOption(
      name: 'studio',
      label: 'Studio Vibrant',
      colorFilter: ColorFilter.matrix([
        1.12, 0.00, 0.00, 0.00, -4.0,
        0.00, 1.10, 0.00, 0.00, -3.0,
        0.00, 0.00, 1.06, 0.00, -2.0,
        0.00, 0.00, 0.00, 1.00,  0.0,
      ]),
    ),
    _FilterOption(
      name: 'clarity',
      label: 'Crisp Clarity',
      colorFilter: ColorFilter.matrix([
        1.15, 0.00, 0.00, 0.00,  6.0,
        0.00, 1.15, 0.00, 0.00,  6.0,
        0.00, 0.00, 1.10, 0.00,  4.0,
        0.00, 0.00, 0.00, 1.00,  0.0,
      ]),
    ),
    _FilterOption(
      name: 'warm',
      label: 'Warm Gold',
      colorFilter: ColorFilter.matrix([
        1.12, 0.00, 0.00, 0.00, 10.0,
        0.00, 1.06, 0.00, 0.00,  6.0,
        0.00, 0.00, 0.94, 0.00, -4.0,
        0.00, 0.00, 0.00, 1.00,  0.0,
      ]),
    ),
    _FilterOption(
      name: 'mono',
      label: 'Monochrome',
      colorFilter: ColorFilter.matrix([
        0.34, 0.55, 0.11, 0.00, 0.0,
        0.34, 0.55, 0.11, 0.00, 0.0,
        0.34, 0.55, 0.11, 0.00, 0.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ]),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.rawBytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedImage = frame.image;
          _isLoading = false;
        });
      }
      codec.dispose();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load image: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  void _rotate90() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetAdjustment() {
    HapticFeedback.selectionClick();
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _rotationQuarterTurns = 0;
      _selectedFilterIndex = 0;
    });
  }

  Future<void> _handleSave() async {
    if (_decodedImage == null || _isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final croppedBytes = await _renderOutputImage();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rendering image: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _renderOutputImage() async {
    if (_decodedImage == null) return null;

    final img = _decodedImage!;
    const outputDimension = 512;
    const center = outputDimension / 2.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, outputDimension + 0.0, outputDimension + 0.0),
    );

    // Exact 1:1 square clipping
    canvas.clipRect(
      const Rect.fromLTWH(0, 0, outputDimension + 0.0, outputDimension + 0.0),
    );

    final isRotated90 = _rotationQuarterTurns % 2 == 1;
    final effectiveWidth = isRotated90 ? img.height.toDouble() : img.width.toDouble();
    final effectiveHeight = isRotated90 ? img.width.toDouble() : img.height.toDouble();

    // Base fill scale so crop frame is completely covered without empty space
    final baseScale = math.max(_cropSize / effectiveWidth, _cropSize / effectiveHeight);
    final ratio = outputDimension / _cropSize;

    // Apply exact transformation
    canvas.translate(center + _offset.dx * ratio, center + _offset.dy * ratio);
    canvas.rotate(_rotationQuarterTurns * math.pi / 2.0);
    canvas.scale(baseScale * _scale * ratio);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    final activeFilter = _filters[_selectedFilterIndex].colorFilter;
    if (activeFilter != null) {
      paint.colorFilter = activeFilter;
    }

    canvas.drawImage(
      img,
      Offset(-img.width / 2.0, -img.height / 2.0),
      paint,
    );

    final picture = recorder.endRecording();
    final renderedImage = picture.toImageSync(outputDimension, outputDimension);
    final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    renderedImage.dispose();

    return byteData?.buffer.asUint8List();
  }

  /// Public accessor for testing and programmatic crop pipeline rendering.
  Future<Uint8List?> renderCroppedBytes() => _renderOutputImage();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = c.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Dialog(
          backgroundColor: c.card,
          surfaceTintColor: Colors.transparent,
          elevation: 24,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.aqua.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.crop_rotate_rounded, size: 20, color: c.aqua),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adjust Profile Picture',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Center your face & customize styling',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Interactive Crop Viewport Frame
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: _cropSize,
                      height: _cropSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(c.aqua),
                              ),
                            )
                          : _errorMessage != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: c.ruby,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onScaleStart: (details) {
                                    _baseScaleOnStart = _scale;
                                    _startFocalPoint = details.focalPoint;
                                    _startOffset = _offset;
                                  },
                                  onScaleUpdate: (details) {
                                    setState(() {
                                      _scale = (_baseScaleOnStart * details.scale)
                                          .clamp(1.0, 3.5);
                                      final delta = details.focalPoint - _startFocalPoint;
                                      _offset = _startOffset + delta;
                                    });
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Image layer with transform
                                      if (_decodedImage != null)
                                        _buildTransformedImage(),

                                      // Circular Cutout Mask & Grid Overlay
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _CircleCropOverlayPainter(
                                              borderColor: c.aqua,
                                              borderWidth: 2.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Alignment Toolbar (Rotate, Reset, Zoom Slider)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.border.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Rotate 90°
                      IconButton(
                        tooltip: 'Rotate 90°',
                        icon: Icon(Icons.rotate_right_rounded, size: 20, color: c.textPrimary),
                        onPressed: _rotate90,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      ),
                      // Reset to center
                      IconButton(
                        tooltip: 'Center & Reset',
                        icon: Icon(Icons.restart_alt_rounded, size: 20, color: c.textSecondary),
                        onPressed: _resetAdjustment,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.zoom_out_rounded, size: 16, color: c.textMuted),
                      // Zoom Slider
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: c.aqua,
                            inactiveTrackColor: c.border,
                            thumbColor: c.aqua,
                          ),
                          child: Slider(
                            value: _scale,
                            min: 1.0,
                            max: 3.5,
                            onChanged: (val) => setState(() => _scale = val),
                          ),
                        ),
                      ),
                      Icon(Icons.zoom_in_rounded, size: 16, color: c.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Portrait Filter Chips Carousel
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PORTRAIT FILTER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, idx) {
                          final f = _filters[idx];
                          final isSelected = _selectedFilterIndex == idx;
                          return SpongyTap(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedFilterIndex = idx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? c.aqua.withValues(alpha: 0.16)
                                    : c.inputFill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? c.aqua
                                      : c.border.withValues(alpha: 0.8),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? c.aqua : c.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Action Buttons (Cancel and Spongy Save)
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SpongyTap(
                        onTap: _isSaving ? () {} : _handleSave,
                        pressScale: 0.965,
                        child: Container(
                          height: 46,
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
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      c.primaryButtonText,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: c.primaryButtonText,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Save Picture',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: c.primaryButtonText,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
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

  Widget _buildTransformedImage() {
    final img = _decodedImage!;
    final isRotated90 = _rotationQuarterTurns % 2 == 1;
    final effectiveWidth = isRotated90 ? img.height.toDouble() : img.width.toDouble();
    final effectiveHeight = isRotated90 ? img.width.toDouble() : img.height.toDouble();

    final baseScale = math.max(_cropSize / effectiveWidth, _cropSize / effectiveHeight);
    final activeFilter = _filters[_selectedFilterIndex].colorFilter;

    Widget imageWidget = RawImage(
      image: img,
      width: img.width.toDouble(),
      height: img.height.toDouble(),
      fit: BoxFit.fill,
    );

    if (activeFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: activeFilter,
        child: imageWidget,
      );
    }

    return Transform.translate(
      offset: _offset,
      child: Transform.rotate(
        angle: _rotationQuarterTurns * math.pi / 2.0,
        child: Transform.scale(
          scale: baseScale * _scale,
          child: imageWidget,
        ),
      ),
    );
  }
}

/// Custom painter that renders a circular cutout with dark vignette and rule-of-thirds grid
class _CircleCropOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;

  _CircleCropOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius = size.width / 2.0;

    // 1. Dark Vignette Outer Path (Everything outside the circle)
    final vignettePath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawPath(
      vignettePath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill,
    );

    // 2. Subtle Rule-of-Thirds Grid inside the circle for perfect face/eye centralization
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final thirdW = size.width / 3.0;
    final thirdH = size.height / 3.0;

    // Vertical grid lines
    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), gridPaint);
    canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), gridPaint);

    // Horizontal grid lines
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), gridPaint);
    canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), gridPaint);

    canvas.restore();

    // 3. Circular Accent Border Ring
    canvas.drawCircle(
      center,
      radius - borderWidth / 2.0,
      Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleCropOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || oldDelegate.borderWidth != borderWidth;
  }
}
