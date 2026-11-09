/// Defines sign up page in the auth feature's presentation layer.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/phone_formatter.dart';
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

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  /// Creates the mutable state object that backs this stateful widget.
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
  CountryCodeOption _selectedCountry = CountryCodeOption.pk;

  // Tapped link tracking for immediate color-flash animation
  String? _tappedLink; // 'privacy' | 'terms'

  // Checkbox bounce animation
  late final AnimationController _checkboxController;
  late final Animation<double> _checkboxScale;

  /// Initializes controllers, listeners, and other state owned by this widget.
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

  /// Releases resources owned by this object before it is removed.
  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _checkboxController.dispose();
    super.dispose();
  }

  /// Updates the selected country code and reformats the phone value.
  void _onCountryChanged(CountryCodeOption newCountry) {
    if (newCountry == _selectedCountry) return;
    HapticFeedback.selectionClick();

    final digits = PhoneFormatter.clean(_phoneController.text);
    final reformatted = digits.isNotEmpty
        ? PhoneFormatter.format(digits, isUs: newCountry.isUs)
        : '';

    setState(() {
      _selectedCountry = newCountry;
      _phoneController.value = TextEditingValue(
        text: reformatted,
        selection: TextSelection.collapsed(offset: reformatted.length),
      );
    });
  }

  /// Returns a human-readable title for server error dialogs based on status code.
  String _serverErrorTitle(int statusCode) {
    switch (statusCode) {
      case 500: return 'Server Error';
      case 502: return 'Gateway Error';
      case 503: return 'Service Unavailable';
      case 504: return 'Gateway Timeout';
      default:  return 'Connection Error';
    }
  }

  /// Validates the fields, registers the local profile, and starts KYC onboarding.
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

    try {
      // Clean and normalize phone number with selected country code
      final rawPhone = _phoneController.text.trim();
      String formattedPhone = '';
      if (rawPhone.isNotEmpty) {
        final cleanDigits = PhoneFormatter.clean(rawPhone);
        String nationalDigits = cleanDigits;
        if (_selectedCountry.isUs) {
          if (nationalDigits.startsWith('1') && nationalDigits.length == 11) {
            nationalDigits = nationalDigits.substring(1);
          }
          if (nationalDigits.isNotEmpty) {
            formattedPhone = '+1 $nationalDigits';
          }
        } else {
          if (nationalDigits.startsWith('92') && nationalDigits.length > 2) {
            nationalDigits = nationalDigits.substring(2);
          } else if (nationalDigits.startsWith('0') && nationalDigits.length > 1) {
            nationalDigits = nationalDigits.substring(1);
          }
          if (nationalDigits.isNotEmpty) {
            formattedPhone = '+92 $nationalDigits';
          }
        }
      }

      final request = SignUpRequest(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: formattedPhone.isNotEmpty ? formattedPhone : null,
        password: _passwordController.text,
        smsConsent: _smsConsentChecked,
      );

      await AuthRepository.instance.signUp(request);

      if (!mounted) return;

      if (AppConfig.hasCustomBackend) {
        _showOtpVerificationDialog(
          email: request.email,
          password: request.password,
        );
      } else {
        PaidiXToast.showSuccess(
          context,
          'Account created successfully! Proceeding to KYC verification.',
        );
        context.go('/kyc');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isRetryable) {
        // 500, 502, 503, 504 — transient server errors → full ServerErrorDialog
        ServerErrorDialog.show(
          context,
          info: ServerErrorInfo(
            statusCode: e.statusCode,
            title: _serverErrorTitle(e.statusCode),
            message: e.message,
            errorCode: e.errorCode ?? 'ERR_SIGNUP_${e.statusCode}',
          ),
          onRetry: () => _handleSignUp(),
        );
      } else if (e.statusCode == 429) {
        final hint = e.retryAfterSeconds != null
            ? ' Try again in ${e.retryAfterSeconds}s.'
            : '';
        PaidiXToast.showWarning(context, '${e.message}$hint');
      } else {
        PaidiXToast.showError(context, e.message);
      }
    } catch (e) {
      if (!mounted) return;
      PaidiXToast.showError(context, 'Sign up failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Displays the OTP email verification modal after signup.
  void _showOtpVerificationDialog({
    required String email,
    required String password,
  }) {
    EmailOtpDialog.show(
      context,
      email: email,
      password: password,
      onVerified: () {
        if (!mounted) return;
        PaidiXToast.showSuccess(
          context,
          'Email verified successfully! Proceeding to KYC onboarding.',
        );
        context.go('/kyc');
      },
    );
  }

  /// Toggles the user's optional SMS consent value.
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

                      // Phone (Optional) Field with country code selector
                      AuthTextField(
                        label: 'Phone (Optional)',
                        placeholder: _selectedCountry.hintText,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          PhoneInputFormatter(isUs: _selectedCountry.isUs),
                        ],
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<CountryCodeOption>(
                                  value: _selectedCountry,
                                  dropdownColor: colors.cardDark,
                                  borderRadius: AppSpacing.radiusMd,
                                  elevation: 8,
                                  menuWidth: 220,
                                  icon: Padding(
                                    padding: const EdgeInsets.only(left: 2, right: 4),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontFamily: AppTheme.activeFontFamily,
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onChanged: (newCountry) {
                                    if (newCountry != null) {
                                      _onCountryChanged(newCountry);
                                    }
                                  },
                                  selectedItemBuilder: (context) {
                                    return CountryCodeOption.values.map((country) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            country.flag,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            country.dialCode,
                                            style: TextStyle(
                                              fontFamily: AppTheme.activeFontFamily,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },
                                  items: CountryCodeOption.values.map((country) {
                                    final isSelected = country == _selectedCountry;
                                    return DropdownMenuItem<CountryCodeOption>(
                                      value: country,
                                      child: Row(
                                        children: [
                                          Text(
                                            country.flag,
                                            style: const TextStyle(fontSize: 15),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              country.name,
                                              style: TextStyle(
                                                fontFamily: AppTheme.activeFontFamily,
                                                color: isSelected
                                                    ? colors.aqua
                                                    : colors.textPrimary,
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            country.display,
                                            style: TextStyle(
                                              fontFamily: AppTheme.activeFontFamily,
                                              color: isSelected
                                                  ? colors.aqua
                                                  : colors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.check_rounded,
                                              size: 15,
                                              color: colors.aqua,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 20,
                                margin: const EdgeInsets.only(left: 4, right: 8),
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
