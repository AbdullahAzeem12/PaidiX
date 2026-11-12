/// Profile Picture Cropper & Confirmation Dialog.
/// Centers the portrait by default without top-heavy bias, allows interactive
/// drag and pinch/slider zoom framing inside the circular avatar mask, and
/// renders a crisp 1:1 512x512 PNG on confirmation.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/spongy_tap.dart';

/// Profile Picture Cropper & Confirmation Dialog.
/// Displays the full photo inside an interactive 1:1 circular crop mask
/// centered by default, supports drag-to-reposition and pinch/slider zoom,
/// and renders a crisp 512x512 square avatar on confirmation.
class ProfilePictureCropDialog extends StatefulWidget {
  final Uint8List rawBytes;

  const ProfilePictureCropDialog({
    super.key,
    required this.rawBytes,
  });

  /// Displays the cropper confirmation dialog and returns 512x512 PNG bytes on confirmation.
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

  /// Renders a 1:1 512x512 PNG square crop from [img] using [alignment] in `[-1, 1]`
  /// and [zoom] `>= 1.0` without distorting aspect ratio or exposing empty edges.
  static Future<Uint8List?> _renderSquarePng(
    ui.Image img, {
    ColorFilter? colorFilter,
    Alignment alignment = Alignment.center,
    double zoom = 1.0,
  }) async {
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    final clampedZoom = zoom.clamp(1.0, 3.0);
    final minDim = math.min(w, h);
    final cropSize = (minDim / clampedZoom).clamp(1.0, minDim);
    final maxX = math.max(0.0, w - cropSize);
    final maxY = math.max(0.0, h - cropSize);
    final normX = ((alignment.x + 1.0) / 2.0).clamp(0.0, 1.0);
    final normY = ((alignment.y + 1.0) / 2.0).clamp(0.0, 1.0);
    final cropX = (maxX * normX).clamp(0.0, maxX);
    final cropY = (maxY * normY).clamp(0.0, maxY);

    const outputDimension = 512;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, outputDimension + 0.0, outputDimension + 0.0),
    );

    final srcRect = Rect.fromLTWH(cropX, cropY, cropSize, cropSize);
    const dstRect =
        Rect.fromLTWH(0, 0, outputDimension + 0.0, outputDimension + 0.0);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }

    canvas.drawImageRect(img, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    final renderedImage = picture.toImageSync(outputDimension, outputDimension);
    final byteData =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);

    renderedImage.dispose();
    picture.dispose();

    return byteData?.buffer.asUint8List();
  }

  /// Automatically computes a centered 1:1 square crop box (or framed with
  /// [alignment] and [zoom]) and renders a 512x512 PNG without distortion.
  static Future<Uint8List> autoCropImage(
    Uint8List rawBytes, {
    ColorFilter? colorFilter,
    Alignment alignment = Alignment.center,
    double zoom = 1.0,
  }) async {
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    try {
      final pngBytes = await _renderSquarePng(
        img,
        colorFilter: colorFilter,
        alignment: alignment,
        zoom: zoom,
      );
      return pngBytes ?? rawBytes;
    } finally {
      img.dispose();
      codec.dispose();
    }
  }

  @override
  State<ProfilePictureCropDialog> createState() =>
      ProfilePictureCropDialogState();
}

class ProfilePictureCropDialogState extends State<ProfilePictureCropDialog> {
  ui.Image? _decodedImage;
  Uint8List? _cachedCenteredBytes;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;
  double _zoom = 1.0;
  double _gestureStartZoom = 1.0;
  Offset _dragOffset = Offset.zero;
  double _activePreviewSize = 188.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    _decodedImage = null;
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.rawBytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final centered =
          await ProfilePictureCropDialog._renderSquarePng(frame.image);
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _decodedImage = frame.image;
        _cachedCenteredBytes = centered;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not process image: $e';
          _isLoading = false;
        });
      }
    }
  }

  ({double renderedW, double renderedH, double maxDx, double maxDy})
      _previewGeometry(double previewSize, double zoom) {
    final img = _decodedImage;
    if (img == null) {
      return (
        renderedW: previewSize,
        renderedH: previewSize,
        maxDx: 0.0,
        maxDy: 0.0,
      );
    }
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    final baseScale = previewSize / math.min(w, h);
    final scale = baseScale * zoom.clamp(1.0, 3.0);
    final renderedW = w * scale;
    final renderedH = h * scale;
    final maxDx = math.max(0.0, (renderedW - previewSize) / 2.0);
    final maxDy = math.max(0.0, (renderedH - previewSize) / 2.0);
    return (
      renderedW: renderedW,
      renderedH: renderedH,
      maxDx: maxDx,
      maxDy: maxDy,
    );
  }

  Offset _clampOffset(Offset rawOffset, double previewSize, double zoom) {
    final geom = _previewGeometry(previewSize, zoom);
    return Offset(
      rawOffset.dx.clamp(-geom.maxDx, geom.maxDx),
      rawOffset.dy.clamp(-geom.maxDy, geom.maxDy),
    );
  }

  Alignment _currentAlignment() {
    final geom = _previewGeometry(_activePreviewSize, _zoom);
    final clamped = _clampOffset(_dragOffset, _activePreviewSize, _zoom);
    final ax =
        geom.maxDx > 0.001 ? (-clamped.dx / geom.maxDx).clamp(-1.0, 1.0) : 0.0;
    final ay =
        geom.maxDy > 0.001 ? (-clamped.dy / geom.maxDy).clamp(-1.0, 1.0) : 0.0;
    return Alignment(ax, ay);
  }

  void _setZoom(double nextZoom) {
    if (_decodedImage == null || _isSaving) return;
    final clamped = nextZoom.clamp(1.0, 3.0);
    setState(() {
      _zoom = clamped;
      _dragOffset = _clampOffset(_dragOffset, _activePreviewSize, clamped);
    });
  }

  void _resetFraming() {
    if (_isSaving) return;
    HapticFeedback.selectionClick();
    setState(() {
      _zoom = 1.0;
      _dragOffset = Offset.zero;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_decodedImage == null || _isSaving) return;
    final nextZoom = (_gestureStartZoom * details.scale).clamp(1.0, 3.0);
    setState(() {
      _zoom = nextZoom;
      _dragOffset = _clampOffset(
        _dragOffset + details.focalPointDelta,
        _activePreviewSize,
        nextZoom,
      );
    });
  }

  bool get _isCenteredUnzoomed =>
      _zoom <= 1.001 && _dragOffset.distance <= 0.5;

  Future<void> _handleSave() async {
    if (_isLoading || _errorMessage != null || _isSaving) return;

    HapticFeedback.mediumImpact();
    if (_isCenteredUnzoomed && _cachedCenteredBytes != null) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(_cachedCenteredBytes);
      }
      return;
    }

    setState(() => _isSaving = true);

    final cropped = await renderCroppedBytes();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(cropped);
    }
  }

  /// Exposes programmatic rendering for confirmation and automated testing suites.
  Future<Uint8List?> renderCroppedBytes() async {
    if (_isCenteredUnzoomed && _cachedCenteredBytes != null) {
      return _cachedCenteredBytes;
    }
    final alignment = _currentAlignment();
    final img = _decodedImage;
    if (img != null) {
      final png = await ProfilePictureCropDialog._renderSquarePng(
        img,
        alignment: alignment,
        zoom: _zoom,
      );
      if (png != null) return png;
    }
    return await ProfilePictureCropDialog.autoCropImage(
      widget.rawBytes,
      alignment: alignment,
      zoom: _zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = c.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final previewSize = math
        .min(
          188.0,
          math.max(
            124.0,
            math.min(screenSize.width - 104, screenSize.height * 0.34),
          ),
        )
        .toDouble();
    _activePreviewSize = previewSize;

    final geom = _previewGeometry(previewSize, _zoom);
    final clampedOffset = _clampOffset(_dragOffset, previewSize, _zoom);
    final hasCustomFraming = _zoom > 1.01 || clampedOffset.distance > 0.5;

    return Dialog(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? c.border.withValues(alpha: 0.8)
              : c.border.withValues(alpha: 0.95),
          width: 1.0,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: screenSize.height * 0.88,
        ),
        child: SingleChildScrollView(
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
                      color: c.aqua.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: c.aqua,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Photo',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Preview before saving',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: c.textMuted),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Clean Interactive Circular Portrait Preview
              Center(
                child: Container(
                  width: previewSize,
                  height: previewSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF031415)
                        : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: c.aqua.withValues(alpha: isDark ? 0.65 : 0.75),
                      width: 2.0,
                    ),
                  ),
                  child: _isLoading
                      ? Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(c.aqua),
                            ),
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: c.ruby, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: _handleScaleStart,
                              onScaleUpdate: _handleScaleUpdate,
                              child: ClipOval(
                                child: SizedBox(
                                  width: previewSize,
                                  height: previewSize,
                                  child: Stack(
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      Positioned(
                                        left: (previewSize - geom.renderedW) /
                                                2.0 +
                                            clampedOffset.dx,
                                        top: (previewSize - geom.renderedH) /
                                                2.0 +
                                            clampedOffset.dy,
                                        width: geom.renderedW,
                                        height: geom.renderedH,
                                        child: RawImage(
                                          image: _decodedImage,
                                          fit: BoxFit.fill,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              if (!_isLoading && _errorMessage == null) ...[
                const SizedBox(height: 12),
                Text(
                  'Drag photo to center • Slide or pinch to zoom',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.zoom_out_rounded, size: 17, color: c.textMuted),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: c.aqua,
                          inactiveTrackColor: c.border,
                          thumbColor: c.aqua,
                          overlayColor: c.aqua.withValues(alpha: 0.18),
                        ),
                        child: Slider(
                          value: _zoom,
                          min: 1.0,
                          max: 3.0,
                          onChanged: _isSaving ? null : _setZoom,
                        ),
                      ),
                    ),
                    Icon(Icons.zoom_in_rounded, size: 17, color: c.textMuted),
                    if (hasCustomFraming) ...[
                      const SizedBox(width: 6),
                      SpongyTap(
                        onTap: _resetFraming,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: c.aqua,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Action Buttons: Cancel vs Save
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: c.border.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(null),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SpongyTap(
                      onTap: _isSaving || _isLoading ? () {} : _handleSave,
                      pressScale: 0.965,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.primaryButton,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    c.primaryButtonText,
                                  ),
                                ),
                              )
                            : Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.primaryButtonText,
                                  letterSpacing: -0.2,
                                ),
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
    );
  }
}
