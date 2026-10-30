import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/spongy_tap.dart';

/// Interactive Document Thumbnail Tile displaying real KYC document uploads
/// or high-fidelity regulatory ID previews with zoom inspection trigger.
class DocumentPreviewTile extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final String? filePath;
  final VoidCallback onTap;
  final bool isSelfie;

  const DocumentPreviewTile({
    super.key,
    required this.label,
    required this.onTap,
    this.bytes,
    this.filePath,
    this.isSelfie = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SpongyTap(
      onTap: onTap,
      pressScale: 0.965,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(
            color: colors.border.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.radiusMd,
          child: Stack(
            children: [
              // Content: Real Image or High-Fidelity Synthetic Document Graphic
              Positioned.fill(
                child: _buildDocumentContent(context, colors, isDark),
              ),

              // Gradient scrim for bottom label contrast
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 38,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF021B1D).withValues(alpha: 0.95),
                        const Color(0xFF021B1D).withValues(alpha: 0.60),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Label Bar matching screenshot exactly
              Positioned(
                left: 10,
                right: 10,
                bottom: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.fullscreen_rounded,
                      size: 14,
                      color: colors.aquaLight.withValues(alpha: 0.85),
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

  Widget _buildDocumentContent(
      BuildContext context, PaidiXColorScheme colors, bool isDark) {
    // 1. If bytes provided in memory
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackGraphic(colors, isDark),
      );
    }

    // 2. If valid file path provided
    if (filePath != null && filePath!.isNotEmpty && !kIsWeb) {
      final file = File(filePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackGraphic(colors, isDark),
        );
      }
    }

    // 3. Fallback High-Fidelity Document Graphic matching screenshot
    return _buildFallbackGraphic(colors, isDark);
  }

  Widget _buildFallbackGraphic(PaidiXColorScheme colors, bool isDark) {
    if (isSelfie) {
      return Container(
        color: const Color(0xFF082729),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.cardHighlight,
                  border: Border.all(
                    color: colors.aqua.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: colors.aquaLight,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'LIVE BIOMETRIC',
                style: TextStyle(
                  color: colors.aquaLight.withValues(alpha: 0.6),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // CNIC Graphic (Front or Back)
    final isFront = label.contains('FRONT');
    return Container(
      color: const Color(0xFF082729),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 16,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                Icons.verified_outlined,
                size: 12,
                color: colors.aqua.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isFront) ...[
            Row(
              children: [
                Container(
                  width: 22,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colors.cardDark,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: colors.borderSubtle, width: 0.8),
                  ),
                  child: Icon(Icons.person, size: 14, color: colors.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 4, width: double.infinity, color: colors.borderSubtle),
                      const SizedBox(height: 3),
                      FractionallySizedBox(
                        widthFactor: 0.7,
                        child: Container(height: 4, color: colors.borderSubtle),
                      ),
                      const SizedBox(height: 3),
                      FractionallySizedBox(
                        widthFactor: 0.85,
                        child: Container(height: 4, color: colors.borderSubtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Container(height: 6, width: double.infinity, color: colors.cardDark),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 3, width: double.infinity, color: colors.borderSubtle),
                      const SizedBox(height: 3),
                      FractionallySizedBox(
                        widthFactor: 0.75,
                        child: Container(height: 3, color: colors.borderSubtle),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.borderSubtle, width: 0.6),
                  ),
                  child: Icon(Icons.qr_code, size: 12, color: colors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
