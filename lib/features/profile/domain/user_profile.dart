/// Defines user profile in the profile feature's domain layer.

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
  final bool hasCompletedKyc;
  final bool smsConsent;

  // Real uploaded or captured document assets
  final Uint8List? selfieBytes;
  final String? selfieFilePath;
  final Uint8List? cnicFrontBytes;
  final String? cnicFrontFilePath;
  final Uint8List? cnicBackBytes;
  final String? cnicBackFilePath;

  // Custom profile avatar
  final Uint8List? avatarBytes;
  final String? avatarFilePath;

  // Linked payout bank details
  final String? bankName;
  final String? bankAccountNumber;
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
    this.hasCompletedKyc = true,
    this.smsConsent = true,
    this.selfieBytes,
    this.selfieFilePath,
    this.cnicFrontBytes,
    this.cnicFrontFilePath,
    this.cnicBackBytes,
    this.cnicBackFilePath,
    this.avatarBytes,
    this.avatarFilePath,
    this.bankName,
    this.bankAccountNumber,
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
      hasCompletedKyc: true,
      smsConsent: true,
      bankName: 'Meezan Bank Limited',
      bankAccountNumber: '01010102030405',
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

  /// Whether the user has an uploaded custom profile photo
  bool get hasCustomAvatar =>
      (avatarBytes != null && avatarBytes!.isNotEmpty) ||
      (avatarFilePath != null && avatarFilePath!.isNotEmpty);

  /// Formatted creation timestamp: e.g. "Oct 29, 2026, 01:09 AM"
  String get formattedCreatedAt => AppFormatters.formatDateTime(createdAt);

  /// Formatted update timestamp: e.g. "Oct 29, 2026, 09:33 PM"
  String get formattedUpdatedAt => AppFormatters.formatDateTime(updatedAt);

  String get displayPhone => phoneNumber.isNotEmpty ? phoneNumber : '—';
  String get displayCnic => cnicNumber.isNotEmpty ? cnicNumber : '—';
  String get displayCity => city.isNotEmpty ? city : '—';
  String get displayAddress => address.isNotEmpty ? address : '—';

  /// Creates a copy while preserving fields that were not supplied.
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
    bool? hasCompletedKyc,
    bool? smsConsent,
    Uint8List? selfieBytes,
    String? selfieFilePath,
    Uint8List? cnicFrontBytes,
    String? cnicFrontFilePath,
    Uint8List? cnicBackBytes,
    String? cnicBackFilePath,
    Uint8List? avatarBytes,
    String? avatarFilePath,
    bool clearAvatar = false,
    String? bankName,
    String? bankAccountNumber,
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
      hasCompletedKyc: hasCompletedKyc ?? this.hasCompletedKyc,
      smsConsent: smsConsent ?? this.smsConsent,
      selfieBytes: selfieBytes ?? this.selfieBytes,
      selfieFilePath: selfieFilePath ?? this.selfieFilePath,
      cnicFrontBytes: cnicFrontBytes ?? this.cnicFrontBytes,
      cnicFrontFilePath: cnicFrontFilePath ?? this.cnicFrontFilePath,
      cnicBackBytes: cnicBackBytes ?? this.cnicBackBytes,
      cnicBackFilePath: cnicBackFilePath ?? this.cnicBackFilePath,
      avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
      avatarFilePath:
          clearAvatar ? null : (avatarFilePath ?? this.avatarFilePath),
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIban: bankIban ?? this.bankIban,
      bankBeneficiary: bankBeneficiary ?? this.bankBeneficiary,
    );
  }

  /// Serializes this value into the JSON shape used by local storage.
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'countryCode': countryCode,
      'phoneNumber': phoneNumber,
      'cnicNumber': cnicNumber,
      'city': city,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'kycStatus': kycStatus.name,
      'hasCompletedKyc': hasCompletedKyc,
      'smsConsent': smsConsent,
      'selfieFilePath': selfieFilePath,
      'cnicFrontFilePath': cnicFrontFilePath,
      'cnicBackFilePath': cnicBackFilePath,
      'avatarFilePath': avatarFilePath,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankIban': bankIban,
      'bankBeneficiary': bankBeneficiary,
    };
  }

  /// Reconstructs this value from its locally stored JSON representation.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '+92',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      cnicNumber: json['cnicNumber'] as String? ?? '',
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      kycStatus: KycReviewStatus.values.firstWhere(
        (e) => e.name == json['kycStatus'],
        orElse: () => KycReviewStatus.pendingReview,
      ),
      hasCompletedKyc: json['hasCompletedKyc'] as bool? ?? false,
      smsConsent: json['smsConsent'] as bool? ?? true,
      selfieFilePath: json['selfieFilePath'] as String?,
      cnicFrontFilePath: json['cnicFrontFilePath'] as String?,
      cnicBackFilePath: json['cnicBackFilePath'] as String?,
      avatarFilePath: json['avatarFilePath'] as String?,
      bankName: json['bankName'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIban: json['bankIban'] as String?,
      bankBeneficiary: json['bankBeneficiary'] as String?,
    );
  }
}
