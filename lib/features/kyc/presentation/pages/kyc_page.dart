import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
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

  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  late KycState _state;

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

  void _goToStep(KycStep step) {
    UserProfileRepository.instance.activeKycStep = step;
    UserProfileRepository.instance.syncFromKyc(_state);
    setState(() {
      _state = _state.copyWith(currentStep: step);
    });
  }

  void _nextStep() {
    UserProfileRepository.instance.syncFromKyc(_state);
    final nextIndex = _state.currentStep.index + 1;
    if (nextIndex < KycStep.values.length) {
      _goToStep(KycStep.values[nextIndex]);
    }
  }

  void _previousStep() {
    UserProfileRepository.instance.syncFromKyc(_state);
    final prevIndex = _state.currentStep.index - 1;
    if (prevIndex >= 0) {
      _goToStep(KycStep.values[prevIndex]);
    }
  }

  void _handleSubmit() {
    setState(() {
      _state = _state.copyWith(isSubmitted: true);
    });
    UserProfileRepository.instance.syncFromKyc(_state);
    UserProfileRepository.instance.markKycCompleted();
    KycSuccessDialog.show(context);
  }

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

