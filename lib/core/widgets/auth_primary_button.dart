import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'app_button.dart';

class AuthPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      width: double.infinity,
      height: 48,
      variant: AppButtonVariant.primary,
      icon: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: colors.primaryButtonText,
      ),
    );
  }
}
