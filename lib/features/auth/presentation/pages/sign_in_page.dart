/// Defines sign in page in the auth feature's presentation layer.

import 'package:flutter/material.dart';
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
import '../../../profile/data/user_profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/auth_validators.dart';

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

  /// Validates the form, resolves the local demo user, and routes by KYC status.
  Future<void> _handleSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      PaidiXToast.showWarning(context, 'Please enter a valid email and password.');
      return;
    }

    setState(() => _isLoading = true);
    // Real integration endpoint boundary
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final inputEmail = _emailController.text.trim().toLowerCase();

    // Backend error simulation handler (for error testing or network failure)
    if (inputEmail.startsWith('error') || inputEmail.startsWith('500')) {
      ServerErrorDialog.show(
        context,
        info: const ServerErrorInfo(
          statusCode: 503,
          title: 'Authentication Gateway Latency',
          message:
              'Unable to reach the core authentication and settlement cluster. Please retry or verify your network connection.',
          errorCode: 'ERR_AUTH_503_UNAVAILABLE',
        ),
        onRetry: () => _handleSignIn(),
      );
      return;
    }

    final repo = UserProfileRepository.instance;
    final registered =
        await repo.findOrLoadUser(inputEmail) ?? repo.findUser(inputEmail);

    // If registered user exists, activate their synchronized profile
    if (registered != null) {
      repo.setActiveUser(registered);
      // If user has already completed KYC, route straight to Dashboard
      if (registered.hasCompletedKyc) {
        PaidiXToast.showSuccess(
          context,
          'Welcome back, ${registered.firstName}! Authenticated successfully.',
        );
        context.go('/app/dashboard');
      } else {
        PaidiXToast.showInfo(
          context,
          'Please complete regulatory KYC onboarding to continue.',
        );
        context.go('/kyc');
      }
      return;
    }

    // Fallback logic preserving admin/verified routes
    if (inputEmail.contains('admin') || inputEmail.contains('verified')) {
      final verifiedUser = UserProfile.defaultProfile().copyWith(
        email: inputEmail,
        hasCompletedKyc: true,
      );
      repo.setActiveUser(verifiedUser);
      PaidiXToast.showSuccess(
        context,
        'Welcome, ${verifiedUser.firstName}! Verified session started.',
      );
      context.go('/app/dashboard');
      return;
    }

    // New unverified customer signing in for the first time must complete KYC
    final newUser = UserProfile(
      fullName: inputEmail.split('@').first,
      email: inputEmail,
      countryCode: '+92',
      phoneNumber: '',
      cnicNumber: '',
      city: '',
      address: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      hasCompletedKyc: false,
      kycStatus: KycReviewStatus.notStarted,
    );
    repo.setActiveUser(newUser);
    PaidiXToast.showInfo(
      context,
      'Welcome to PaidiX! Please proceed with regulatory KYC.',
    );
    context.go('/kyc');
  }

  /// Shows the simulated password-recovery instructions dialog.
  void _showForgotPasswordDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusLg,
          side: BorderSide(color: colors.border, width: 1.2),
        ),
        title: Text(
          'Reset Password',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Password recovery instructions will be sent to your registered email address.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          SpongyLinkButton(
            text: 'Send Link',
            onTap: () {
              Navigator.of(ctx).pop();
              PaidiXToast.showSuccess(
                context,
                'Password recovery instructions sent to registered email.',
              );
            },
            normalColor: colors.aqua,
            activeColor: colors.aquaLight,
          ),
          SpongyLinkButton(
            text: 'Close',
            onTap: () => Navigator.of(ctx).pop(),
            normalColor: colors.textSecondary,
            activeColor: colors.textPrimary,
          ),
        ],
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
                        onPressed: _handleSignIn,
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
