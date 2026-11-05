/// Defines kyc page in the kyc feature's presentation layer.

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/paidix_toast.dart';
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

  const KycPage({
    super.key,
    this.initialStep = KycStep.personal,
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

    final effectiveStep = widget.initialStep != KycStep.personal
        ? widget.initialStep
        : UserProfileRepository.instance.activeKycStep;

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
        frontBytes: profile.cnicFrontBytes,
        frontFilePath: profile.cnicFrontFilePath,
        backBytes: profile.cnicBackBytes,
        backFilePath: profile.cnicBackFilePath,
      ),
      photo: PhotoDocInfo(
        bytes: profile.selfieBytes,
        filePath: profile.selfieFilePath,
      ),
      bank: BankInfo(
        bankName: (profile.bankName != null && profile.bankName!.isNotEmpty)
            ? profile.bankName!
            : 'Meezan Bank Limited',
        beneficiaryTitle: (profile.bankBeneficiary != null &&
                profile.bankBeneficiary!.isNotEmpty)
            ? profile.bankBeneficiary!
            : profile.fullName,
        iban: profile.bankIban ?? '',
      ),
    );
  }

  /// Saves the current KYC data and moves the form to [step].
  void _goToStep(KycStep step) {
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
      switch (nextStep) {
        case KycStep.identity:
          PaidiXToast.showSuccess(
            context,
            'Personal info saved. Proceeding to ID verification.',
          );
          break;
        case KycStep.photo:
          PaidiXToast.showSuccess(
            context,
            'ID documents recorded. Proceeding to biometric selfie.',
          );
          break;
        case KycStep.bank:
          PaidiXToast.showSuccess(
            context,
            'Biometrics verified. Final step: Link bank account.',
          );
          break;
        case KycStep.personal:
          break;
      }
      _goToStep(nextStep);
    }
  }

  /// Saves current form data and moves back one KYC step when possible.
  void _previousStep() {
    UserProfileRepository.instance.syncFromKyc(_state);
    final prevIndex = _state.currentStep.index - 1;
    if (prevIndex >= 0) {
      _goToStep(KycStep.values[prevIndex]);
    }
  }

  /// Marks KYC complete, syncs the submitted data, and opens the success dialog.
  void _handleSubmit() {
    setState(() {
      _state = _state.copyWith(isSubmitted: true);
    });
    UserProfileRepository.instance.syncFromKyc(_state);
    UserProfileRepository.instance.markKycCompleted();
    PaidiXToast.showSuccess(
      context,
      'KYC documents submitted successfully for 1-LINK clearance.',
    );
    KycSuccessDialog.show(context);
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

