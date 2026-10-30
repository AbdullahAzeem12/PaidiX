import 'package:flutter/foundation.dart';
import '../../kyc/domain/kyc_models.dart';
import '../domain/user_profile.dart';

/// Central singleton repository managing reactive synchronization of the
/// active user's profile and KYC document state.
///
/// Follows PaidiX architecture (single process-memory ValueNotifier,
/// identical to PaymentsRepositoryImpl).
class UserProfileRepository {
  UserProfileRepository._internal();

  static final UserProfileRepository instance = UserProfileRepository._internal();
  factory UserProfileRepository() => instance;

  final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(UserProfile.defaultProfile());

  UserProfile get profile => profileNotifier.value;

  /// Synchronize details entered during the initial Sign-Up step
  void syncFromSignUp({
    required String fullName,
    required String email,
    String? phoneNumber,
    bool smsConsent = true,
  }) {
    final current = profileNotifier.value;
    profileNotifier.value = current.copyWith(
      fullName: fullName.trim(),
      email: email.trim(),
      phoneNumber: (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          ? phoneNumber.trim()
          : current.phoneNumber,
      smsConsent: smsConsent,
      updatedAt: DateTime.now(),
    );
  }

  /// Synchronize all steps captured during regulatory KYC onboarding
  void syncFromKyc(KycState kycState) {
    final current = profileNotifier.value;

    final p = kycState.personal;
    final id = kycState.identity;
    final photo = kycState.photo;
    final bank = kycState.bank;

    // Determine clean phone representation
    final country = p.countryCode.trim().isNotEmpty ? p.countryCode : current.countryCode;
    final rawPhone = p.phoneNumber.trim();
    final combinedPhone = rawPhone.isNotEmpty
        ? (rawPhone.startsWith('+') ? rawPhone : '$country$rawPhone')
        : current.phoneNumber;

    profileNotifier.value = current.copyWith(
      fullName: p.fullName.trim().isNotEmpty ? p.fullName.trim() : current.fullName,
      countryCode: country,
      phoneNumber: combinedPhone,
      address: (p.address != null && p.address!.trim().isNotEmpty)
          ? p.address!.trim()
          : current.address,
      city: (p.city != null && p.city!.trim().isNotEmpty)
          ? p.city!.trim()
          : current.city,
      cnicNumber: id.cnicNumber.trim().isNotEmpty ? id.cnicNumber.trim() : current.cnicNumber,
      // Front and Back CNIC bytes/paths (prefer enhanced bytes if present)
      cnicFrontBytes: id.enhancedFrontBytes ?? id.frontBytes ?? current.cnicFrontBytes,
      cnicFrontFilePath: id.frontFilePath ?? current.cnicFrontFilePath,
      cnicBackBytes: id.enhancedBackBytes ?? id.backBytes ?? current.cnicBackBytes,
      cnicBackFilePath: id.backFilePath ?? current.cnicBackFilePath,
      // Selfie bytes/paths
      selfieBytes: photo.enhancedBytes ?? photo.bytes ?? current.selfieBytes,
      selfieFilePath: photo.filePath ?? current.selfieFilePath,
      // Bank details
      bankName: bank.bankName.isNotEmpty ? bank.bankName : current.bankName,
      bankIban: bank.iban.isNotEmpty ? bank.iban : current.bankIban,
      bankBeneficiary: bank.beneficiaryTitle.isNotEmpty
          ? bank.beneficiaryTitle
          : current.bankBeneficiary,
      kycStatus: KycReviewStatus.pendingReview,
      updatedAt: DateTime.now(),
    );
  }

  /// Update personal information and documents from the "Edit Profile" action
  void updateProfile({
    String? fullName,
    String? phoneNumber,
    String? cnicNumber,
    String? city,
    String? address,
    KycReviewStatus? kycStatus,
    Uint8List? selfieBytes,
    String? selfieFilePath,
    Uint8List? cnicFrontBytes,
    String? cnicFrontFilePath,
    Uint8List? cnicBackBytes,
    String? cnicBackFilePath,
  }) {
    final current = profileNotifier.value;
    profileNotifier.value = current.copyWith(
      fullName: fullName != null && fullName.trim().isNotEmpty
          ? fullName.trim()
          : current.fullName,
      phoneNumber: phoneNumber != null && phoneNumber.trim().isNotEmpty
          ? phoneNumber.trim()
          : current.phoneNumber,
      cnicNumber: cnicNumber != null && cnicNumber.trim().isNotEmpty
          ? cnicNumber.trim()
          : current.cnicNumber,
      city: city != null ? city.trim() : current.city,
      address: address != null ? address.trim() : current.address,
      kycStatus: kycStatus ?? current.kycStatus,
      selfieBytes: selfieBytes ?? current.selfieBytes,
      selfieFilePath: selfieFilePath ?? current.selfieFilePath,
      cnicFrontBytes: cnicFrontBytes ?? current.cnicFrontBytes,
      cnicFrontFilePath: cnicFrontFilePath ?? current.cnicFrontFilePath,
      cnicBackBytes: cnicBackBytes ?? current.cnicBackBytes,
      cnicBackFilePath: cnicBackFilePath ?? current.cnicBackFilePath,
      updatedAt: DateTime.now(),
    );
  }

  /// Reset to standard canonical profile
  void resetToDefault() {
    profileNotifier.value = UserProfile.defaultProfile();
  }
}

