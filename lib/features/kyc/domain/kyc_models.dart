/// Defines kyc models in the kyc feature's domain layer.

import 'dart:typed_data';
import '../../../core/utils/bank_account_validator.dart';

enum KycStep {
  personal(1, 'Personal', 'Tell us about you.',
      'Basic details we\'ll use on your profile.'),
  identity(2, 'Identity', 'Verify your identity.',
      'Upload clear photos of both sides of your CNIC.'),
  photo(3, 'Photo', 'Upload your photo.',
      'A clear photo of you holding your CNIC. We use this to confirm identity and as your profile picture.'),
  bank(4, 'PK Bank', 'Link your Pakistani Bank Account.',
      'Where you want your PKR payouts deposited upon payment verification.');

  final int stepNumber;
  final String label;
  final String title;
  final String subtitle;

  const KycStep(this.stepNumber, this.label, this.title, this.subtitle);
}

enum EnhancementStatus {
  idle,
  processing,
  enhanced,
  failed,
}

class PersonalInfo {
  final String fullName;
  final String countryCode;
  final String phoneNumber;
  final bool smsConsent;
  final String? address;
  final String? city;

  const PersonalInfo({
    this.fullName = '',
    this.countryCode = '+92',
    this.phoneNumber = '',
    this.smsConsent = false,
    this.address,
    this.city,
  });

  bool get isValid {
    final cleanDigits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final isUs =
        countryCode.contains('+1') || countryCode.toUpperCase().contains('US');

    final bool isPhoneValid;
    if (isUs) {
      isPhoneValid = cleanDigits.length == 10 &&
          (int.tryParse(cleanDigits.isNotEmpty ? cleanDigits[0] : '0') ?? 0) >=
              2;
    } else {
      isPhoneValid = cleanDigits.length >= 7 && cleanDigits.length <= 11;
    }

    return fullName.trim().length >= 3 && isPhoneValid && smsConsent;
  }

  /// Creates a copy while preserving fields that were not supplied.
  PersonalInfo copyWith({
    String? fullName,
    String? countryCode,
    String? phoneNumber,
    bool? smsConsent,
    String? address,
    String? city,
  }) {
    return PersonalInfo(
      fullName: fullName ?? this.fullName,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      smsConsent: smsConsent ?? this.smsConsent,
      address: address ?? this.address,
      city: city ?? this.city,
    );
  }
}

class IdentityDocInfo {
  final String cnicNumber;
  final bool isAvailable;
  final String? frontFileName;
  final String? frontFilePath;
  final Uint8List? frontBytes;
  final String? backFileName;
  final String? backFilePath;
  final Uint8List? backBytes;
  final bool isEnhanced;
  final Uint8List? enhancedFrontBytes;
  final Uint8List? enhancedBackBytes;

  const IdentityDocInfo({
    this.cnicNumber = '',
    this.isAvailable = true,
    this.frontFileName,
    this.frontFilePath,
    this.frontBytes,
    this.backFileName,
    this.backFilePath,
    this.backBytes,
    this.isEnhanced = false,
    this.enhancedFrontBytes,
    this.enhancedBackBytes,
  });

  bool get hasFiles =>
      (frontFileName != null || frontFilePath != null || frontBytes != null) &&
      (backFileName != null || backFilePath != null || backBytes != null);

  bool get isValid => cnicNumber.trim().isNotEmpty && hasFiles;

  /// Creates a copy while preserving fields that were not supplied.
  IdentityDocInfo copyWith({
    String? cnicNumber,
    bool? isAvailable,
    String? frontFileName,
    String? frontFilePath,
    Uint8List? frontBytes,
    String? backFileName,
    String? backFilePath,
    Uint8List? backBytes,
    bool? isEnhanced,
    Uint8List? enhancedFrontBytes,
    Uint8List? enhancedBackBytes,
  }) {
    return IdentityDocInfo(
      cnicNumber: cnicNumber ?? this.cnicNumber,
      isAvailable: isAvailable ?? this.isAvailable,
      frontFileName: frontFileName ?? this.frontFileName,
      frontFilePath: frontFilePath ?? this.frontFilePath,
      frontBytes: frontBytes ?? this.frontBytes,
      backFileName: backFileName ?? this.backFileName,
      backFilePath: backFilePath ?? this.backFilePath,
      backBytes: backBytes ?? this.backBytes,
      isEnhanced: isEnhanced ?? this.isEnhanced,
      enhancedFrontBytes: enhancedFrontBytes ?? this.enhancedFrontBytes,
      enhancedBackBytes: enhancedBackBytes ?? this.enhancedBackBytes,
    );
  }
}

class PhotoDocInfo {
  final String? fileName;
  final String? filePath;
  final Uint8List? bytes;
  final bool isCameraCapture;
  final bool isEnhanced;
  final Uint8List? enhancedBytes;

  const PhotoDocInfo({
    this.fileName,
    this.filePath,
    this.bytes,
    this.isCameraCapture = false,
    this.isEnhanced = false,
    this.enhancedBytes,
  });

  bool get hasPhoto => fileName != null || filePath != null || bytes != null;

  /// Creates a copy while preserving fields that were not supplied.
  PhotoDocInfo copyWith({
    String? fileName,
    String? filePath,
    Uint8List? bytes,
    bool? isCameraCapture,
    bool? isEnhanced,
    Uint8List? enhancedBytes,
  }) {
    return PhotoDocInfo(
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      isCameraCapture: isCameraCapture ?? this.isCameraCapture,
      isEnhanced: isEnhanced ?? this.isEnhanced,
      enhancedBytes: enhancedBytes ?? this.enhancedBytes,
    );
  }
}

class BankInfo {
  final String bankName;
  final String beneficiaryTitle;
  final String accountNumber;
  final String iban;
  final bool is1LinkVerified;

  const BankInfo({
    this.bankName = 'Meezan Bank Limited',
    this.beneficiaryTitle = '',
    this.accountNumber = '',
    this.iban = '',
    this.is1LinkVerified = true,
  });

  bool get isValid {
    if (bankName.isEmpty || beneficiaryTitle.trim().length < 3) {
      return false;
    }

    final hasValidAcc = accountNumber.isNotEmpty
        ? BankAccountValidator.isAccountNumberValid(bankName, accountNumber)
        : (iban.trim().length >= 14); // Backward-compatible fallback

    if (!hasValidAcc) return false;

    // IBAN is optional: if empty, valid. If entered, must be valid.
    return iban.trim().isEmpty || BankAccountValidator.isIbanValid(iban);
  }

  /// Creates a copy while preserving fields that were not supplied.
  BankInfo copyWith({
    String? bankName,
    String? beneficiaryTitle,
    String? accountNumber,
    String? iban,
    bool? is1LinkVerified,
  }) {
    return BankInfo(
      bankName: bankName ?? this.bankName,
      beneficiaryTitle: beneficiaryTitle ?? this.beneficiaryTitle,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      is1LinkVerified: is1LinkVerified ?? this.is1LinkVerified,
    );
  }
}

class KycState {
  final KycStep currentStep;
  final PersonalInfo personal;
  final IdentityDocInfo identity;
  final PhotoDocInfo photo;
  final BankInfo bank;
  final EnhancementStatus enhancementStatus;
  final double enhancementProgress;
  final String enhancementStageMessage;
  final bool isSubmitted;

  const KycState({
    this.currentStep = KycStep.personal,
    this.personal = const PersonalInfo(),
    this.identity = const IdentityDocInfo(),
    this.photo = const PhotoDocInfo(),
    this.bank = const BankInfo(),
    this.enhancementStatus = EnhancementStatus.idle,
    this.enhancementProgress = 0.0,
    this.enhancementStageMessage = '',
    this.isSubmitted = false,
  });

  /// Creates a copy while preserving fields that were not supplied.
  KycState copyWith({
    KycStep? currentStep,
    PersonalInfo? personal,
    IdentityDocInfo? identity,
    PhotoDocInfo? photo,
    BankInfo? bank,
    EnhancementStatus? enhancementStatus,
    double? enhancementProgress,
    String? enhancementStageMessage,
    bool? isSubmitted,
  }) {
    return KycState(
      currentStep: currentStep ?? this.currentStep,
      personal: personal ?? this.personal,
      identity: identity ?? this.identity,
      photo: photo ?? this.photo,
      bank: bank ?? this.bank,
      enhancementStatus: enhancementStatus ?? this.enhancementStatus,
      enhancementProgress: enhancementProgress ?? this.enhancementProgress,
      enhancementStageMessage:
          enhancementStageMessage ?? this.enhancementStageMessage,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}
