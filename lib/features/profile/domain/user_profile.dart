import 'dart:typed_data';
import '../../../core/utils/formatters.dart';

/// KYC status for user profile and regulatory compliance
enum KycReviewStatus {
  notStarted('Not Started'),
  inProgress('In Progress'),
  pendingReview('Pending Review'),
  verified('Verified'),
  rejected('Rejected');

  final String label;
  const KycReviewStatus(this.label);

  bool get isPending => this == KycReviewStatus.pendingReview;
  bool get isVerified => this == KycReviewStatus.verified;
}

/// Domain entity representing the active user's synchronized profile
/// and regulatory KYC identity documents on file.
class UserProfile {
  final String fullName;
  final String email;
  final String countryCode;
  final String phoneNumber;
  final String cnicNumber;
  final String city;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final KycReviewStatus kycStatus;
  final bool smsConsent;

  // Real uploaded or captured document assets
  final Uint8List? selfieBytes;
  final String? selfieFilePath;
  final Uint8List? cnicFrontBytes;
  final String? cnicFrontFilePath;
  final Uint8List? cnicBackBytes;
  final String? cnicBackFilePath;

  // Linked payout bank details
  final String? bankName;
  final String? bankIban;
  final String? bankBeneficiary;

  const UserProfile({
    required this.fullName,
    required this.email,
    this.countryCode = '+92',
    required this.phoneNumber,
    required this.cnicNumber,
    required this.city,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
    this.kycStatus = KycReviewStatus.pendingReview,
    this.smsConsent = true,
    this.selfieBytes,
    this.selfieFilePath,
    this.cnicFrontBytes,
    this.cnicFrontFilePath,
    this.cnicBackBytes,
    this.cnicBackFilePath,
    this.bankName,
    this.bankIban,
    this.bankBeneficiary,
  });

  /// Canonical initial profile matching verified screenshot prototype
  factory UserProfile.defaultProfile() {
    return UserProfile(
      fullName: 'Abdullah Azeem',
      email: 'kherool66@gmail.com',
      countryCode: '+92',
      phoneNumber: '+923217649976',
      cnicNumber: '35202-04504615',
      city: 'لاہور',
      address: 'Canalberg Housing Society',
      createdAt: DateTime(2026, 10, 29, 1, 9),
      updatedAt: DateTime(2026, 10, 29, 21, 33),
      kycStatus: KycReviewStatus.pendingReview,
      smsConsent: true,
      bankName: 'Meezan Bank Limited',
      bankIban: null,
      bankBeneficiary: 'Abdullah Azeem',
    );
  }

  /// First name for greetings (e.g. "Hello, Abdullah.")
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'User';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Single initial letter for avatar circle
  String get avatarInitial {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed[0].toUpperCase();
  }

  /// Formatted creation timestamp: e.g. "Oct 29, 2026, 01:09 AM"
  String get formattedCreatedAt => AppFormatters.formatDateTime(createdAt);

  /// Formatted update timestamp: e.g. "Oct 29, 2026, 09:33 PM"
  String get formattedUpdatedAt => AppFormatters.formatDateTime(updatedAt);

  String get displayPhone => phoneNumber.isNotEmpty ? phoneNumber : '—';
  String get displayCnic => cnicNumber.isNotEmpty ? cnicNumber : '—';
  String get displayCity => city.isNotEmpty ? city : '—';
  String get displayAddress => address.isNotEmpty ? address : '—';

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? cnicNumber,
    String? city,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    KycReviewStatus? kycStatus,
    bool? smsConsent,
    Uint8List? selfieBytes,
    String? selfieFilePath,
    Uint8List? cnicFrontBytes,
    String? cnicFrontFilePath,
    Uint8List? cnicBackBytes,
    String? cnicBackFilePath,
    String? bankName,
    String? bankIban,
    String? bankBeneficiary,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      city: city ?? this.city,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kycStatus: kycStatus ?? this.kycStatus,
      smsConsent: smsConsent ?? this.smsConsent,
      selfieBytes: selfieBytes ?? this.selfieBytes,
      selfieFilePath: selfieFilePath ?? this.selfieFilePath,
      cnicFrontBytes: cnicFrontBytes ?? this.cnicFrontBytes,
      cnicFrontFilePath: cnicFrontFilePath ?? this.cnicFrontFilePath,
      cnicBackBytes: cnicBackBytes ?? this.cnicBackBytes,
      cnicBackFilePath: cnicBackFilePath ?? this.cnicBackFilePath,
      bankName: bankName ?? this.bankName,
      bankIban: bankIban ?? this.bankIban,
      bankBeneficiary: bankBeneficiary ?? this.bankBeneficiary,
    );
  }
}
