/// Defines user profile in the profile feature's domain layer.

import 'dart:typed_data';
import '../../../core/utils/formatters.dart';

/// KYC status for user profile and regulatory compliance
enum KycReviewStatus {
  notStarted('Not Started'),
  inProgress('In Progress'),
  pendingReview('Pending Review'),
  verified('Verified'),
  rejected('Verification Rejected');

  final String label;
  const KycReviewStatus(this.label);

  bool get isPending => this == KycReviewStatus.pendingReview;
  bool get isVerified => this == KycReviewStatus.verified;
  bool get isRejected => this == KycReviewStatus.rejected;
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
  final String? selfieUrl;
  final Uint8List? cnicFrontBytes;
  final String? cnicFrontFilePath;
  final String? cnicFrontUrl;
  final Uint8List? cnicBackBytes;
  final String? cnicBackFilePath;
  final String? cnicBackUrl;

  // Custom profile avatar
  final Uint8List? avatarBytes;
  final String? avatarFilePath;

  // Linked payout bank details
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIban;
  final String? bankBeneficiary;

  // Realtime backend KYC rejection metadata
  final String? kycRejectionReason;
  final List<String> kycObjections;
  final DateTime? kycReviewedAt;

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
    this.selfieUrl,
    this.cnicFrontBytes,
    this.cnicFrontFilePath,
    this.cnicFrontUrl,
    this.cnicBackBytes,
    this.cnicBackFilePath,
    this.cnicBackUrl,
    this.avatarBytes,
    this.avatarFilePath,
    this.bankName,
    this.bankAccountNumber,
    this.bankIban,
    this.bankBeneficiary,
    this.kycRejectionReason,
    this.kycObjections = const [],
    this.kycReviewedAt,
  });

  /// Initial unauthenticated clean profile for the application.
  factory UserProfile.empty() {
    final now = DateTime.now();
    return UserProfile(
      fullName: '',
      email: '',
      countryCode: '+92',
      phoneNumber: '',
      cnicNumber: '',
      city: '',
      address: '',
      createdAt: now,
      updatedAt: now,
      kycStatus: KycReviewStatus.notStarted,
      hasCompletedKyc: false,
      smsConsent: false,
      kycRejectionReason: null,
      kycObjections: const [],
    );
  }

  /// Returns the dynamic message from the server side or default status label.
  String get effectiveKycMessage {
    if (kycStatus == KycReviewStatus.rejected) {
      if (kycRejectionReason != null && kycRejectionReason!.trim().isNotEmpty) {
        return kycRejectionReason!.trim();
      }
      if (kycObjections.isNotEmpty) {
        return kycObjections.join('\n');
      }
      return 'Verification Rejected';
    }
    return kycStatus.label;
  }

  /// First name for greetings.
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
  String? get formattedKycReviewedAt => kycReviewedAt == null
      ? null
      : AppFormatters.formatDateTime(kycReviewedAt!);

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
    String? selfieUrl,
    Uint8List? cnicFrontBytes,
    String? cnicFrontFilePath,
    String? cnicFrontUrl,
    Uint8List? cnicBackBytes,
    String? cnicBackFilePath,
    String? cnicBackUrl,
    Uint8List? avatarBytes,
    String? avatarFilePath,
    bool clearAvatar = false,
    String? bankName,
    String? bankAccountNumber,
    String? bankIban,
    String? bankBeneficiary,
    String? kycRejectionReason,
    List<String>? kycObjections,
    DateTime? kycReviewedAt,
    bool clearKycReviewedAt = false,
    bool clearRejection = false,
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
      selfieUrl: selfieUrl ?? this.selfieUrl,
      cnicFrontBytes: cnicFrontBytes ?? this.cnicFrontBytes,
      cnicFrontFilePath: cnicFrontFilePath ?? this.cnicFrontFilePath,
      cnicFrontUrl: cnicFrontUrl ?? this.cnicFrontUrl,
      cnicBackBytes: cnicBackBytes ?? this.cnicBackBytes,
      cnicBackFilePath: cnicBackFilePath ?? this.cnicBackFilePath,
      cnicBackUrl: cnicBackUrl ?? this.cnicBackUrl,
      avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
      avatarFilePath:
          clearAvatar ? null : (avatarFilePath ?? this.avatarFilePath),
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIban: bankIban ?? this.bankIban,
      bankBeneficiary: bankBeneficiary ?? this.bankBeneficiary,
      kycRejectionReason: clearRejection
          ? null
          : (kycRejectionReason ?? this.kycRejectionReason),
      kycObjections:
          clearRejection ? const [] : (kycObjections ?? this.kycObjections),
      kycReviewedAt:
          clearKycReviewedAt ? null : (kycReviewedAt ?? this.kycReviewedAt),
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
      'selfieUrl': selfieUrl,
      'cnicFrontFilePath': cnicFrontFilePath,
      'cnicFrontUrl': cnicFrontUrl,
      'cnicBackFilePath': cnicBackFilePath,
      'cnicBackUrl': cnicBackUrl,
      'avatarFilePath': avatarFilePath,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankIban': bankIban,
      'bankBeneficiary': bankBeneficiary,
      'kycRejectionReason': kycRejectionReason,
      'kycObjections': kycObjections,
      'kycReviewedAt': kycReviewedAt?.toIso8601String(),
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
      selfieUrl: json['selfieUrl'] as String?,
      cnicFrontFilePath: json['cnicFrontFilePath'] as String?,
      cnicFrontUrl: json['cnicFrontUrl'] as String?,
      cnicBackFilePath: json['cnicBackFilePath'] as String?,
      cnicBackUrl: json['cnicBackUrl'] as String?,
      avatarFilePath: json['avatarFilePath'] as String?,
      bankName: json['bankName'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIban: json['bankIban'] as String?,
      bankBeneficiary: json['bankBeneficiary'] as String?,
      kycRejectionReason: json['kycRejectionReason'] as String?,
      kycObjections: (json['kycObjections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      kycReviewedAt: json['kycReviewedAt'] is String
          ? DateTime.tryParse(json['kycReviewedAt'] as String)
          : null,
    );
  }
}
