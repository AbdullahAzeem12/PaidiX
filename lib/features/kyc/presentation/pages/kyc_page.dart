/// Defines kyc page in the kyc feature's presentation layer.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/kyc_repository.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../domain/kyc_models.dart';
import '../widgets/kyc_header.dart';
import '../widgets/kyc_stepper.dart';
import '../widgets/kyc_success_dialog.dart';
import '../widgets/step1_personal_view.dart';
import '../widgets/step2_identity_view.dart';
import '../widgets/step3_photo_view.dart';
import '../widgets/step4_bank_view.dart';

class KycPage extends StatefulWidget {
  final KycStep initialStep;
  final bool resubmission;

  const KycPage({
    super.key,
    this.initialStep = KycStep.personal,
    this.resubmission = false,
  });

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  late KycState _state;

  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    final profile = UserProfileRepository.instance.profile;

    final effectiveStep = widget.resubmission
        ? KycStep.personal
        : widget.initialStep != KycStep.personal
            ? widget.initialStep
            : UserProfileRepository.instance.activeKycStep;
    if (widget.resubmission) {
      UserProfileRepository.instance.activeKycStep = KycStep.personal;
    }

    _state = KycState(
      currentStep: effectiveStep,
      personal: PersonalInfo(
        fullName: profile.fullName,
        countryCode:
            profile.countryCode.isNotEmpty ? profile.countryCode : '+92',
        phoneNumber: profile.phoneNumber,
        smsConsent: profile.smsConsent,
        address: profile.address.isNotEmpty ? profile.address : null,
        city: profile.city.isNotEmpty ? profile.city : null,
      ),
      identity: IdentityDocInfo(
        cnicNumber: profile.cnicNumber,
        frontBytes: widget.resubmission ? null : profile.cnicFrontBytes,
        frontFilePath: widget.resubmission ? null : profile.cnicFrontFilePath,
        backBytes: widget.resubmission ? null : profile.cnicBackBytes,
        backFilePath: widget.resubmission ? null : profile.cnicBackFilePath,
      ),
      photo: PhotoDocInfo(
        bytes: widget.resubmission ? null : profile.selfieBytes,
        filePath: widget.resubmission ? null : profile.selfieFilePath,
      ),
      bank: BankInfo(
        bankName: (profile.bankName != null && profile.bankName!.isNotEmpty)
            ? profile.bankName!
            : 'Meezan Bank Limited',
        beneficiaryTitle: (profile.bankBeneficiary != null &&
                profile.bankBeneficiary!.isNotEmpty)
            ? profile.bankBeneficiary!
            : profile.fullName,
        accountNumber: profile.bankAccountNumber ?? '',
        iban: profile.bankIban ?? '',
      ),
    );

    if (AppConfig.hasCustomBackend && !widget.resubmission) {
      _loadServerDraft();
    }
  }

  /// Restores any previously saved onboarding step and fields from the server.
  Future<void> _loadServerDraft() async {
    try {
      final draft = await KycRepository.instance.getOnboardingProgress();
      if (!mounted || draft.isEmpty) return;

      final goto = draft['goto'] as int? ?? draft['onboarding_step'] as int?;
      final data = draft['data'] as Map<String, dynamic>? ?? {};

      setState(() {
        if (data.isNotEmpty) {
          final serverPhone =
              (data['phone'] ?? data['phoneNumber']) as String? ?? '';
          final serverFullName =
              (data['full_name'] ?? data['fullName']) as String? ?? '';
          final serverAddress = data['address'] as String? ?? '';
          final serverCity = data['city'] as String? ?? '';
          final serverCnic =
              (data['cnic_number'] ?? data['cnicNumber']) as String? ?? '';

          _state = _state.copyWith(
            personal: _state.personal.copyWith(
              fullName: serverFullName.isNotEmpty
                  ? serverFullName
                  : _state.personal.fullName,
              phoneNumber: serverPhone.isNotEmpty
                  ? serverPhone
                  : _state.personal.phoneNumber,
              address: serverAddress.isNotEmpty
                  ? serverAddress
                  : _state.personal.address,
              city: serverCity.isNotEmpty ? serverCity : _state.personal.city,
            ),
            identity: _state.identity.copyWith(
              cnicNumber: serverCnic.isNotEmpty
                  ? serverCnic
                  : _state.identity.cnicNumber,
            ),
          );
        }

        if (goto != null && goto >= 0 && goto < KycStep.values.length) {
          final targetStep = KycStep.values[goto];
          _goToStep(targetStep);
        }
      });

      // If phone is still not populated, check /auth/me/
      if (_state.personal.phoneNumber.isEmpty) {
        try {
          final me = await AuthRepository.instance.fetchCurrentUserProfile();
          final mePhone = (me['phone'] ?? me['phoneNumber']) as String? ?? '';
          final meFullName =
              (me['full_name'] ?? me['fullName']) as String? ?? '';
          if (mounted && (mePhone.isNotEmpty || meFullName.isNotEmpty)) {
            setState(() {
              _state = _state.copyWith(
                personal: _state.personal.copyWith(
                  phoneNumber: mePhone.isNotEmpty
                      ? mePhone
                      : _state.personal.phoneNumber,
                  fullName: meFullName.isNotEmpty
                      ? meFullName
                      : _state.personal.fullName,
                ),
              );
            });
            UserProfileRepository.instance.syncFromKyc(_state);
          }
        } catch (_) {}
      }
    } catch (_) {
      // Non-blocking draft load fallback
    }
  }

  /// Saves the current KYC data and moves the form to [step].
  void _goToStep(KycStep step) {
    if (_isSubmitting) return;
    UserProfileRepository.instance.activeKycStep = step;
    UserProfileRepository.instance.syncFromKyc(_state);
    setState(() {
      _state = _state.copyWith(currentStep: step);
    });
  }

  /// Saves current form data, announces the next stage, and advances one step.
  void _nextStep() {
    UserProfileRepository.instance.syncFromKyc(_state);
    final nextIndex = _state.currentStep.index + 1;
    if (nextIndex < KycStep.values.length) {
      final nextStep = KycStep.values[nextIndex];
      _goToStep(nextStep);

      // Asynchronously sync step draft to backend
      if (AppConfig.hasCustomBackend) {
        final digits = PhoneFormatter.clean(_state.personal.phoneNumber);
        final apiPhone = _state.personal.countryCode.contains('US') ||
                _state.personal.countryCode.contains('+1')
            ? '+1$digits'
            : (digits.isNotEmpty ? '+92$digits' : _state.personal.phoneNumber);

        KycRepository.instance.saveOnboardingStepDraft(
          step: nextIndex,
          fields: {
            'full_name': _state.personal.fullName,
            'phone': apiPhone,
            'address': _state.personal.address ?? '',
            'city': _state.personal.city ?? '',
            'cnic_number': _state.identity.cnicNumber,
          },
        );
      }
    }
  }

  /// Saves current form data and moves back one KYC step when possible.
  void _previousStep() {
    if (_isSubmitting) return;
    UserProfileRepository.instance.syncFromKyc(_state);
    final prevIndex = _state.currentStep.index - 1;
    if (prevIndex >= 0) {
      _goToStep(KycStep.values[prevIndex]);
    }
  }

  bool _isSubmitting = false;
  double _submitProgress = 0.0;
  double _progressCeiling = 0.68;
  String _submitStatusLabel = 'Submitting Verification...';
  Timer? _progressCreepTimer;

  @override
  void dispose() {
    _progressCreepTimer?.cancel();
    super.dispose();
  }

  /// Advances submission progress smoothly toward [_progressCeiling] during active uploads.
  void _startProgressCreep() {
    _progressCreepTimer?.cancel();
    _progressCreepTimer = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) {
        if (!mounted || !_isSubmitting) {
          _progressCreepTimer?.cancel();
          return;
        }
        if (_submitProgress < _progressCeiling - 0.005) {
          setState(() {
            final step = (_progressCeiling - _submitProgress) * 0.08;
            _submitProgress = (_submitProgress + step.clamp(0.004, 0.03))
                .clamp(0.0, _progressCeiling);
          });
        }
      },
    );
  }

  /// Marks KYC complete, syncs the submitted data, and opens the success dialog.
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submitProgress = 0.08;
      _progressCeiling = 0.68;
      _submitStatusLabel = 'Preparing verification...';
    });
    _startProgressCreep();

    try {
      await KycRepository.instance.submitKyc(
        _state,
        onProgress: (progress, label) {
          if (!mounted) return;
          setState(() {
            if (progress > _submitProgress) {
              _submitProgress = progress;
            }
            _submitStatusLabel = label;
            if (progress < 0.70) {
              _progressCeiling = 0.68;
            } else if (progress < 0.90) {
              _progressCeiling = 0.88;
            } else {
              _progressCeiling = 0.98;
            }
          });
        },
      );

      _progressCreepTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _submitProgress = 1.0;
        _submitStatusLabel = 'Verification submitted!';
        _state = _state.copyWith(isSubmitted: true);
      });

      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;

      PaidiXToast.showSuccess(
        context,
        'KYC documents submitted successfully for 1-LINK clearance.',
      );
      KycSuccessDialog.show(
        context,
        resubmission: widget.resubmission,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      PaidiXToast.showError(context, 'KYC submission error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      PaidiXToast.showError(context, 'Unable to submit KYC: $e');
    } finally {
      _progressCreepTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitProgress = 0.0;
        });
      }
    }
  }

  /// Builds the widget subtree from its current properties and inherited context.
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 400 ? 12.0 : 20.0;
    final verticalPadding = screenWidth < 400 ? 16.0 : 28.0;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Fixed Top Header matching screenshots
          const KycHeader(),

          // Main Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stepper progress indicator
                      KycStepper(
                        currentStep: _state.currentStep,
                        onStepTapped: (step) => _goToStep(step),
                      ),
                      if (widget.resubmission) ...[
                        const SizedBox(height: 16),
                        _buildResubmissionNotice(),
                      ],
                      SizedBox(height: screenWidth < 400 ? 18 : 28),

                      // Animated Step Transitions
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_state.currentStep),
                          child: _buildCurrentStepView(),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResubmissionNotice() {
    const rejection = Color(0xFFBE123C);
    final colors = AppColors.of(context);
    final profile = UserProfileRepository.instance.profile;
    final reason = profile.effectiveKycMessage;
    final hasSpecificReason = reason != 'Verification Rejected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rejection.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rejection.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 19, color: rejection),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC was rejected. Correct the details and upload all three documents again.',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasSpecificReason) ...[
                  const SizedBox(height: 5),
                  Text(
                    reason,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the current step view section of this interface.
  Widget _buildCurrentStepView() {
    switch (_state.currentStep) {
      case KycStep.personal:
        return Step1PersonalView(
          personalInfo: _state.personal,
          onChanged: (info) {
            setState(() {
              _state = _state.copyWith(personal: info);
            });
          },
          onContinue: _nextStep,
        );

      case KycStep.identity:
        return Step2IdentityView(
          identityInfo: _state.identity,
          onChanged: (info) {
            setState(() {
              _state = _state.copyWith(identity: info);
            });
            UserProfileRepository.instance.syncFromKyc(_state);
          },
          onNextStep: _nextStep,
          onBack: _previousStep,
        );

      case KycStep.photo:
        return Step3PhotoView(
          photoInfo: _state.photo,
          onChanged: (info) {
            setState(() {
              _state = _state.copyWith(photo: info);
            });
            UserProfileRepository.instance.syncFromKyc(_state);
          },
          onNextStep: _nextStep,
          onBack: _previousStep,
        );

      case KycStep.bank:
        return Step4BankView(
          bankInfo: _state.bank,
          isSubmitting: _isSubmitting,
          submitProgress: _submitProgress,
          submitStatusLabel: _submitStatusLabel,
          onChanged: (info) {
            setState(() {
              _state = _state.copyWith(bank: info);
            });
          },
          onSubmit: _handleSubmit,
          onBack: _previousStep,
        );
    }
  }
}
