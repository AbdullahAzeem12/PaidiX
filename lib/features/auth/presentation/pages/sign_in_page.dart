/// Defines sign in page in the auth feature's presentation layer.

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/auth_header.dart';
import '../../../../core/widgets/auth_primary_button.dart';
import '../../../../core/widgets/auth_text_field.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/server_error_page.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/email_otp_dialog.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';
import '../../domain/auth_validators.dart';
import '../widgets/admin_web_login_dialog.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the form, authenticates via AuthRepository, and routes by KYC status.
  Future<void> _handleSignIn({bool allowOtpDialog = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      PaidiXToast.showWarning(
          context, 'Please enter a valid email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final inputEmail = _emailController.text.trim().toLowerCase();
      final result = await AuthRepository.instance.signIn(
        SignInRequest(
          email: inputEmail,
          password: _passwordController.text,
        ),
      );

      if (!mounted) return;

      if (result.profile.hasCompletedKyc) {
        PaidiXToast.showSuccess(
          context,
          'Welcome back, ${result.profile.firstName}! Authenticated successfully.',
        );
        context.go('/app/dashboard');
      } else {
        PaidiXToast.showInfo(
          context,
          'Please complete regulatory KYC onboarding to continue.',
        );
        context.go('/kyc');
      }
    } on MobileAdminAccessException catch (e) {
      if (!mounted) return;
      await AdminWebLoginDialog.show(context, backendMessage: e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (allowOtpDialog &&
          (e is EmailUnverifiedException ||
              AuthRepository.isEmailUnverifiedError(e))) {
        final otpSent = e is EmailUnverifiedException ? e.otpSent : true;
        final resendNotice =
            e is EmailUnverifiedException ? e.resendNotice : null;
        _showOtpVerificationDialog(
          _emailController.text.trim().toLowerCase(),
          otpSentInitially: otpSent,
          initialErrorMessage: resendNotice,
        );
      } else if (e.isRetryable) {
        // 500, 502, 503, 504 — transient server errors → full ServerErrorDialog
        ServerErrorDialog.show(
          context,
          info: ServerErrorInfo(
            statusCode: e.statusCode,
            title: _serverErrorTitle(e.statusCode),
            message: e.message,
            errorCode: e.errorCode ?? 'ERR_AUTH_${e.statusCode}',
          ),
          onRetry: () => _handleSignIn(),
        );
      } else if (e.statusCode == 429) {
        // 429 Too Many Requests — rate limited
        final hint = e.retryAfterSeconds != null
            ? ' Try again in ${e.retryAfterSeconds}s.'
            : '';
        PaidiXToast.showWarning(context, '${e.message}$hint');
      } else {
        // 400, 401, 403, 404, 409 — show specific error message
        PaidiXToast.showError(context, e.message);
      }
    } catch (e) {
      if (!mounted) return;
      PaidiXToast.showError(context, 'Authentication failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Returns a human-readable title for server error dialogs based on status code.
  String _serverErrorTitle(int statusCode) {
    switch (statusCode) {
      case 500:
        return 'Server Error';
      case 502:
        return 'Gateway Error';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        return 'Connection Error';
    }
  }

  /// Displays the OTP email verification modal.
  void _showOtpVerificationDialog(
    String email, {
    bool otpSentInitially = true,
    String? initialErrorMessage,
  }) {
    EmailOtpDialog.show(
      context,
      email: email,
      password: _passwordController.text,
      otpSentInitially: otpSentInitially,
      initialErrorMessage: initialErrorMessage,
      performSignInOnVerified: false,
      onVerified: () {
        if (!mounted) return;
        PaidiXToast.showSuccess(context, 'Email verified! Signing you in...');
        _handleSignIn(allowOtpDialog: false);
      },
    );
  }

  /// Shows the password recovery dialog with live OTP reset workflow.
  void _showForgotPasswordDialog() {
    final colors = AppColors.of(context);
    final emailController = TextEditingController(
      text: _emailController.text.trim().toLowerCase(),
    );
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    int currentStep = 1; // 1: Email input, 2: Code & New Password
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final viewportSize = MediaQuery.sizeOf(ctx);
          final isCompactWidth = viewportSize.width < 400;

          return AlertDialog(
            backgroundColor: colors.card,
            scrollable: true,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isCompactWidth ? 16 : 24,
              vertical: 16,
            ),
            titlePadding: EdgeInsets.fromLTRB(
              isCompactWidth ? 20 : 24,
              isCompactWidth ? 18 : 22,
              isCompactWidth ? 20 : 24,
              8,
            ),
            contentPadding: EdgeInsets.fromLTRB(
              isCompactWidth ? 20 : 24,
              8,
              isCompactWidth ? 20 : 24,
              12,
            ),
            actionsPadding: EdgeInsets.fromLTRB(
              isCompactWidth ? 16 : 20,
              4,
              isCompactWidth ? 16 : 20,
              16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppSpacing.radiusLg,
              side: BorderSide(color: colors.border, width: 1.2),
            ),
            title: Text(
              currentStep == 1 ? 'Reset Password' : 'Enter Reset Code',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentStep == 1) ...[
                    Text(
                      'Enter your registered email address to receive a 6-digit password reset code.',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.radiusMd,
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'A 6-digit reset code was sent to ${emailController.text}. Enter the code and your new password:',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        labelText: '6-Digit Code',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.radiusMd,
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        filled: true,
                        fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.radiusMd,
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email =
                            emailController.text.trim().toLowerCase();
                        if (email.isEmpty) {
                          PaidiXToast.showWarning(
                              context, 'Please enter your email.');
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          if (currentStep == 1) {
                            if (AppConfig.hasCustomBackend) {
                              await AuthRepository.instance
                                  .requestPasswordResetOtp(email: email);
                            }
                            setDialogState(() {
                              currentStep = 2;
                              isSubmitting = false;
                            });
                            if (!mounted) return;
                            PaidiXToast.showSuccess(
                                context, 'Reset code sent to $email');
                          } else {
                            final code = codeController.text.trim();
                            final newPassword = newPasswordController.text;
                            if (code.length != 6) {
                              PaidiXToast.showWarning(
                                  context, 'Please enter the 6-digit code.');
                              setDialogState(() => isSubmitting = false);
                              return;
                            }
                            if (newPassword.length < 8) {
                              PaidiXToast.showWarning(context,
                                  'Password must be at least 8 characters.');
                              setDialogState(() => isSubmitting = false);
                              return;
                            }

                            if (AppConfig.hasCustomBackend) {
                              await AuthRepository.instance
                                  .resetPasswordWithOtp(
                                email: email,
                                code: code,
                                newPassword: newPassword,
                              );
                            }
                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            _passwordController.text = newPassword;
                            PaidiXToast.showSuccess(
                              context,
                              'Password updated! You can now log in with your new password.',
                            );
                          }
                        } on ApiException catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (!mounted) return;
                          PaidiXToast.showError(context, e.message);
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (!mounted) return;
                          PaidiXToast.showError(
                              context, 'Reset request failed: $e');
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.aqua,
                  foregroundColor: Colors.white,
                  shape:
                      RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        currentStep == 1 ? 'Send Code' : 'Update Password',
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 14 : 24,
              vertical: isNarrow ? 20 : 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: EdgeInsets.all(isNarrow ? 18 : 28),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: AppSpacing.radiusXl,
                  border: Border.all(color: colors.border, width: 1.2),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Block
                      const AuthHeader(
                        eyebrow: 'SIGN IN',
                        title: 'Welcome back.',
                        subtitle: 'Enter your credentials to continue.',
                      ),
                      const SizedBox(height: 32),

                      // Email Field
                      AuthTextField(
                        label: 'Email',
                        placeholder: 'you@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: AuthValidators.validateEmail,
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      AuthTextField(
                        label: 'Password',
                        placeholder: '••••••••',
                        controller: _passwordController,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onTogglePasswordVisibility: () {
                          setState(
                              () => _isPasswordVisible = !_isPasswordVisible);
                        },
                        validator: AuthValidators.validatePassword,
                      ),
                      const SizedBox(height: 14),

                      // Forgot Password Link with spongy effect & color illumination
                      Align(
                        alignment: Alignment.centerRight,
                        child: SpongyLinkButton(
                          text: 'Forgot password?',
                          onTap: _showForgotPasswordDialog,
                          normalColor: colors.aquaLight,
                          activeColor: colors.aqua,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      AuthPrimaryButton(
                        text: 'Sign in',
                        isLoading: _isLoading,
                        onPressed: () => _handleSignIn(),
                      ),
                      const SizedBox(height: 32),

                      // Divider
                      Divider(color: colors.divider, thickness: 1),
                      const SizedBox(height: 24),

                      // Footer Switch Link with spongy bounce & ripple
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'New to PaidiX? ',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: colors.textSecondary,
                              ),
                            ),
                            SpongyLinkButton(
                              text: 'Create an account',
                              onTap: () => context.go('/signup'),
                              normalColor: colors.aqua,
                              activeColor: colors.aquaLight,
                              style: AppTypography.linkText,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
