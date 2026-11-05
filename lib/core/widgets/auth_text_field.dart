/// Defines auth text field in the application core utilities and reusable widgets.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'spongy_tap.dart';

class AuthTextField extends StatelessWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final bool isPassword;
  final bool isPasswordVisible;
  final VoidCallback? onTogglePasswordVisibility;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final bool enabled;
  final Widget? prefix;
  final Widget? prefixIcon;
  final BoxConstraints? prefixIconConstraints;
  final List<TextInputFormatter>? inputFormatters;

  const AuthTextField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.controller,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onTogglePasswordVisibility,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.prefix,
    this.prefixIcon,
    this.prefixIconConstraints,
    this.inputFormatters,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.label.copyWith(color: colors.textLabel),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          validator: validator,
          style: AppTypography.inputText.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            prefix: prefix,
            prefixIcon: prefixIcon,
            prefixIconConstraints: prefixIconConstraints,
            hintText: placeholder,
            hintStyle: AppTypography.inputPlaceholder.copyWith(
              color: colors.textPlaceholder,
            ),
            filled: true,
            fillColor: colors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: BorderSide(color: colors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: BorderSide(color: colors.borderFocused, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: BorderSide(color: colors.borderError, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: BorderSide(color: colors.borderError, width: 1.5),
            ),
            suffixIcon: isPassword
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SpongyTap(
                      onTap: onTogglePasswordVisibility,
                      pressScale: 0.86,
                      borderRadius: BorderRadius.circular(20),
                      splashColor: colors.aqua.withValues(alpha: 0.25),
                      highlightColor: colors.aqua.withValues(alpha: 0.10),
                      padding: const EdgeInsets.all(10),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: Icon(
                          isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          key: ValueKey<bool>(isPasswordVisible),
                          color: isPasswordVisible
                              ? colors.aquaLight
                              : colors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
