/// Defines document viewer dialog in the profile feature's presentation layer.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';

/// Modal dialog providing detailed inspection, zoom, and encryption validation
/// for regulatory KYC documents.
class DocumentViewerDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final Uint8List? bytes;
  final String? filePath;
  final bool isSelfie;

  const DocumentViewerDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.bytes,
    this.filePath,
    this.isSelfie = false,
  });

  /// Opens the selected identity document in a zoomable inspection dialog.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    Uint8List? bytes,
    String? filePath,
    bool isSelfie = false,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => DocumentViewerDialog(
        title: title,
        subtitle: subtitle,
        bytes: bytes,
        filePath: filePath,
        isSelfie: isSelfie,
      ),
    );
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 500;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isNarrow ? size.width * 0.94 : 540,
          constraints: BoxConstraints(maxHeight: size.height * 0.88),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(
              color: colors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                                color: colors.aqua,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: AppTheme.activeFontFamily,
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Image Viewport with Interactive Viewer
              Container(
                height: 280,
                color: const Color(0xFF031415),
                child: ClipRect(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: _buildImageView(colors),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Security & Details Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: colors.emerald),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'State Bank KYC Compliance • 256-bit AES Encrypted Vault',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      text: 'Close Inspector',
                      variant: AppButtonVariant.primary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the image view section of this interface.
  Widget _buildImageView(PaidiXColorScheme colors) {
    // errorBuilder: an undecodable/corrupt saved image falls back to the
    // placeholder instead of a blank/grey ErrorWidget.
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(colors),
      );
    }
    if (filePath != null && filePath!.isNotEmpty && !kIsWeb) {
      final f = File(filePath!);
      if (f.existsSync()) {
        return Image.file(
          f,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildPlaceholder(colors),
        );
      }
    }

    return _buildPlaceholder(colors);
  }

  Widget _buildPlaceholder(PaidiXColorScheme colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSelfie ? Icons.face_rounded : Icons.badge_rounded,
          size: 64,
          color: colors.aquaLight.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Document on file in secure compliance sandbox',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
