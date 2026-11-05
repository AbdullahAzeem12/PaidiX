import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../core/widgets/auth_header.dart';
import '../../../../core/widgets/auth_primary_button.dart';
import '../../../../core/widgets/auth_text_field.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../domain/auth_validators.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _smsConsentChecked = false;
  bool _isLoading = false;

  // Tapped link tracking for immediate color-flash animation
  String? _tappedLink; // 'privacy' | 'terms'

  // Checkbox bounce animation
  late final AnimationController _checkboxController;
  late final Animation<double> _checkboxScale;

  @override
  void initState() {
    super.initState();
    _checkboxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _checkboxScale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(
        parent: _checkboxController,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _checkboxController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      PaidiXToast.showWarning(context, 'Please complete all required fields.');
      return;
    }

    if (!_smsConsentChecked) {
      PaidiXToast.showWarning(
        context,
        'Please check the box to agree to SMS notifications and terms.',
      );
      return;
    }

    setState(() => _isLoading = true);
    // Real integration endpoint boundary
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Clean and normalize phone number with default PK (+92) country code
    final rawPhone = _phoneController.text.trim();
    String formattedPhone = '';
    if (rawPhone.isNotEmpty) {
      final cleanDigits = PhoneFormatter.clean(rawPhone);
      // Strip leading 92 or 0 if user pasted it
      String nationalDigits = cleanDigits;
      if (nationalDigits.startsWith('92') && nationalDigits.length > 2) {
        nationalDigits = nationalDigits.substring(2);
      } else if (nationalDigits.startsWith('0') && nationalDigits.length > 1) {
        nationalDigits = nationalDigits.substring(1);
      }
      if (nationalDigits.isNotEmpty) {
        formattedPhone = '+92 $nationalDigits';
      }
    }

    // Sync signed-up user credentials into global repository
    UserProfileRepository.instance.syncFromSignUp(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: formattedPhone,
      smsConsent: _smsConsentChecked,
    );

    PaidiXToast.showSuccess(
      context,
      'Account created successfully! Proceeding to KYC verification.',
    );

    // Newly registered accounts proceed to regulatory KYC verification
    context.go('/kyc');
  }

  void _toggleSmsConsent() {
    // Trigger spongy checkbox bounce
    _checkboxController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) {
          _checkboxController.reverse();
          setState(() => _smsConsentChecked = !_smsConsentChecked);
        }
      });
    });
  }

  /// Opens a URL and briefly flashes the link color to give immediate feedback.
  Future<void> _openLink(String linkKey, String url) async {
    setState(() => _tappedLink = linkKey);
    // Flash for 320ms then revert
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _tappedLink = null);
    });
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Returns the current color for a link span based on tap state.
  Color _linkColor(String linkKey, Color normal, Color active) {
    return _tappedLink == linkKey ? active : normal;
  }

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
                        eyebrow: 'CREATE ACCOUNT',
                        title: 'Start sending.',
                        subtitle:
                            "We'll create your account and send a verification code to your email.",
                      ),
                      const SizedBox(height: 32),

                      // Full Name Field
                      AuthTextField(
                        label: 'Full Name',
                        placeholder: 'Your full name',
                        controller: _fullNameController,
                        validator: AuthValidators.validateFullName,
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      AuthTextField(
                        label: 'Email',
                        placeholder: 'you@company.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: AuthValidators.validateEmail,
                      ),
                      const SizedBox(height: 20),

                      // Phone (Optional) Field with default +92 country code
                      AuthTextField(
                        label: 'Phone (Optional)',
                        placeholder: '300 1234567',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          PhoneInputFormatter(isUs: false),
                        ],
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🇵🇰',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '+92',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 1,
                                height: 20,
                                color: colors.border,
                              ),
                            ],
                          ),
                        ),
                        validator: AuthValidators.validatePhoneOptional,
                      ),
                      const SizedBox(height: 18),

                      // ─── SMS Consent Checkbox ────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Animated spongy checkbox
                          AnimatedBuilder(
                            animation: _checkboxController,
                            builder: (context, _) {
                              return Transform.scale(
                                scale: _checkboxScale.value,
                                child: GestureDetector(
                                  onTap: _toggleSmsConsent,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _smsConsentChecked
                                          ? colors.aqua
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _smsConsentChecked
                                            ? colors.aqua
                                            : colors.border,
                                        width: 1.5,
                                      ),
                                      boxShadow: _smsConsentChecked
                                          ? [
                                              BoxShadow(
                                                color: colors.aqua
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: _smsConsentChecked
                                        ? Icon(
                                            Icons.check,
                                            size: 15,
                                            color: const Color(0xFF031415),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Main SMS consent text
                                Text.rich(
                                  textAlign: TextAlign.justify,
                                  TextSpan(
                                    style: AppTypography.legalText.copyWith(
                                        color: colors.textSecondary),
                                    children: const [
                                      TextSpan(
                                        text:
                                            'By checking this box, I agree to receive SMS text messages from Paidix Global at the phone number provided, including account and payment notifications, customer care, and marketing messages. Reply STOP to opt out.',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // "See our Privacy Policy and Terms of Service"
                                // on its own new line, left-aligned
                                Text.rich(
                                  TextSpan(
                                    style: AppTypography.legalText.copyWith(
                                        color: colors.textSecondary),
                                    children: [
                                      const TextSpan(text: 'See our '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w600,
                                          color: AnimatedColorValue(
                                            current: _linkColor(
                                              'privacy',
                                              colors.aquaLight,
                                              Colors.white,
                                            ),
                                          ).color,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _openLink(
                                                'privacy',
                                                'https://paidix.com/privacy',
                                              ),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w600,
                                          color: AnimatedColorValue(
                                            current: _linkColor(
                                              'terms',
                                              colors.aquaLight,
                                              Colors.white,
                                            ),
                                          ).color,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _openLink(
                                                'terms',
                                                'https://paidix.com/terms',
                                              ),
                                      ),
                                      const TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      AuthTextField(
                        label: 'Password',
                        placeholder: 'At least 8 characters',
                        controller: _passwordController,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onTogglePasswordVisibility: () {
                          setState(
                              () => _isPasswordVisible = !_isPasswordVisible);
                        },
                        validator: AuthValidators.validatePassword,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button with soft spongy effect, bounce, ripple & color glow
                      AuthPrimaryButton(
                        text: 'Create Account',
                        isLoading: _isLoading,
                        onPressed: _handleSignUp,
                      ),
                      const SizedBox(height: 18),

                      // Terms & KYC disclaimer under button
                      Center(
                        child: Text.rich(
                          textAlign: TextAlign.center,
                          TextSpan(
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    "By creating an account, you agree to PaidiX's ",
                              ),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                  color: _linkColor(
                                    'terms_footer',
                                    colors.aquaLight,
                                    Colors.white,
                                  ),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _openLink(
                                        'terms_footer',
                                        'https://paidix.com/terms',
                                      ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                  color: _linkColor(
                                    'privacy_footer',
                                    colors.aquaLight,
                                    Colors.white,
                                  ),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _openLink(
                                        'privacy_footer',
                                        'https://paidix.com/privacy',
                                      ),
                              ),
                              const TextSpan(
                                text:
                                    '.\nYour information is used only for KYC verification and processing your payments.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Divider
                      Divider(color: colors.divider, thickness: 1),
                      const SizedBox(height: 24),

                      // Footer Switch Link — "Sign in" with spongy bounce, color flash,
                      // and slide+fade page transition handled in router
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: colors.textSecondary,
                              ),
                            ),
                            SpongyLinkButton(
                              text: 'Sign in',
                              onTap: () => context.go('/signin'),
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

/// Helper to make setState-driven color changes compile cleanly
/// in TextSpan (which can't use AnimatedDefaultTextStyle).
/// Color is resolved at build time from the parent setState call.
class AnimatedColorValue {
  final Color color;
  const AnimatedColorValue({required Color current}) : color = current;
}
