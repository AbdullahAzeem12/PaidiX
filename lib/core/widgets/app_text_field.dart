/// Defines app text field in the application core utilities and reusable widgets.

import 'package:material_ui/material_ui.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final String? subtext;
  final TextEditingController? controller;
  final bool isPassword;
  final bool isPasswordVisible;
  final VoidCallback? onTogglePasswordVisibility;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final bool enabled;
  final bool isRequired;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  const AppTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.subtext,
    this.controller,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onTogglePasswordVisibility,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.isRequired = false,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.label.copyWith(color: colors.textLabel),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: colors.borderError,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: AppTypography.inputText.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTypography.inputPlaceholder.copyWith(
              color: colors.textPlaceholder,
            ),
            filled: true,
            fillColor: colors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: prefix,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: onTogglePasswordVisibility,
                  )
                : suffix,
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
          ),
        ),
        if (subtext != null) ...[
          const SizedBox(height: 6),
          Text(
            subtext!,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
