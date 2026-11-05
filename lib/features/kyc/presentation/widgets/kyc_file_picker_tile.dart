/// Defines kyc file picker tile in the kyc feature's presentation layer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class KycFilePickerTile extends StatefulWidget {
  final String label;
  final String? fileName;
  final VoidCallback onBrowse;
  final String helperText;
  final bool hasFile;

  const KycFilePickerTile({
    super.key,
    required this.label,
    required this.onBrowse,
    this.fileName,
    this.helperText = 'PNG / JPEG only — PDFs are not accepted',
    this.hasFile = false,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<KycFilePickerTile> createState() => _KycFilePickerTileState();
}

class _KycFilePickerTileState extends State<KycFilePickerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Starts the pressed visual state while the pointer is held down.
  void _onTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  /// Ends the pressed visual state and completes the tap callback.
  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  /// Clears the pressed visual state when a gesture is interrupted.
  void _onTapCancel() {
    _controller.reverse();
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (widget.hasFile) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: colors.emerald,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Picker Box
        Container(
          decoration: BoxDecoration(
            color: colors.inputBackground,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: widget.hasFile
                  ? colors.emerald.withValues(alpha: 0.5)
                  : colors.border.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    widget.fileName ?? 'Choose a file...',
                    style: TextStyle(
                      color: widget.fileName != null
                          ? colors.textPrimary
                          : colors.textMuted,
                      fontSize: 13,
                      fontWeight: widget.fileName != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Animated Spring Bounce-Back BROWSE Button with Ripple Effect
              GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onBrowse,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      splashColor: colors.aqua.withValues(alpha: 0.25),
                      highlightColor: colors.aqua.withValues(alpha: 0.12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: colors.border.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'BROWSE',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),

        // Helper text
        Text(
          widget.helperText,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
