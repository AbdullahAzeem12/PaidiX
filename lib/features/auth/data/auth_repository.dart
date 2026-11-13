/// Authentication repository connecting PaidiX to the backend auth services.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../kyc/data/kyc_image_validation.dart';
import '../../kyc/data/kyc_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/bank_account_item.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/auth_models.dart';

/// Encapsulates authentication result with user profile and session token.
class AuthResult {
  final UserProfile profile;
  final String token;

  const AuthResult({required this.profile, required this.token});
}

/// Thrown when sign-in is blocked because the user's email is unverified.
///
/// Tracks whether a fresh verification OTP was actually dispatched by
/// `POST /auth/email/resend/` (`otpSent`) and any notice/rate-limit detail
/// returned by the server (`resendNotice`).
class EmailUnverifiedException extends ApiException {
  final bool otpSent;
  final String? resendNotice;

  const EmailUnverifiedException({
    required super.message,
    this.otpSent = true,
    this.resendNotice,
    super.statusCode = 401,
    super.errorCode = 'EMAIL_UNVERIFIED',
  });
}

/// Thrown when `POST /auth/email/resend/` reports the email is already verified
/// so callers can complete sign-in directly instead of pretending an OTP was sent.
class EmailAlreadyVerifiedException extends ApiException {
  const EmailAlreadyVerifiedException({
    required super.message,
    super.statusCode = 400,
    super.errorCode = 'EMAIL_ALREADY_VERIFIED',
  });
}

/// Login succeeded at the transport level, but this privileged account must
/// use the PaidiX web application instead of the mobile client.
class MobileAdminAccessException extends ApiException {
  const MobileAdminAccessException({
    required super.message,
    super.statusCode = 403,
    super.errorCode = 'ADMIN_WEB_ONLY',
  });
}

class AuthRepository {
  AuthRepository._() {
    UserProfileRepository.instance.profileNotifier.addListener(
      _syncWithProfileReset,
    );
  }

  static final AuthRepository instance = AuthRepository._();

  final ApiClient _client = ApiClient.instance;

  String? _serverConfirmedKycEmail;
  KycReviewStatus? _serverConfirmedKycStatus;
  Future<KycReviewStatus?>? _kycStatusRefreshInFlight;

  static const _kycRejectionReasonKeys = [
    'kyc_rejection_reason',
    'kycRejectionReason',
    'rejection_reason',
    'rejectionReason',
    'objection_reason',
    'objectionReason',
    'kyc_review_reason',
    'kycReviewReason',
    'kyc_rejection_message',
    'kycRejectionMessage',
    'rejection_message',
    'rejectionMessage',
    'kyc_review_notes',
    'kycReviewNotes',
    'kyc_rejection_comment',
    'kycRejectionComment',
    'kyc_review_comment',
    'kycReviewComment',
    'reviewer_comment',
    'reviewerComment',
    'review_comment',
    'reviewComment',
    'review_notes',
    'reviewNotes',
    'rejection_notes',
    'rejectionNotes',
    'admin_comment',
    'adminComment',
    'admin_reason',
    'adminReason',
    'admin_note',
    'adminNote',
    'rejection_note',
    'rejectionNote',
    'rejection_comment',
    'rejectionComment',
    'kyc_notes',
    'kycNotes',
    'reviewer_note',
    'reviewerNote',
    'comment',
    'reason',
  ];

  /// Broadcasts live server-confirmed KYC review status transitions in the active session.
  final ValueNotifier<KycReviewStatus?> serverKycStatusNotifier =
      ValueNotifier<KycReviewStatus?>(null);

  void _syncWithProfileReset() {
    final current = UserProfileRepository.instance.profile;
    if (current.email.isEmpty &&
        current.kycStatus == KycReviewStatus.notStarted) {
      clearServerKycStatus();
    }
  }

  void _recordServerKycStatus(String email, KycReviewStatus? status) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || status == null) return;
    _serverConfirmedKycEmail = normalized;
    _serverConfirmedKycStatus = status;
    if (serverKycStatusNotifier.value != status) {
      serverKycStatusNotifier.value = status;
    }
  }

  /// Clears cached session-level server KYC confirmation on logout or account switch.
  void clearServerKycStatus() {
    _serverConfirmedKycEmail = null;
    _serverConfirmedKycStatus = null;
    serverKycStatusNotifier.value = null;
  }

  /// Returns the last server-confirmed KYC status for [email] in the current runtime session.
  KycReviewStatus? serverConfirmedKycStatusFor(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || _serverConfirmedKycEmail != normalized) {
      return null;
    }
    return _serverConfirmedKycStatus;
  }

  /// Returns true when [email] has already been confirmed KYC-verified by the backend in this session.
  bool isServerKycVerifiedFor(String email) {
    return serverConfirmedKycStatusFor(email) == KycReviewStatus.verified;
  }

  /// Returns true when a backend error message indicates the email is already verified.
  static bool isAlreadyVerifiedMessage(String message) {
    final msg = message.toLowerCase();
    return msg.contains('already verified') || msg.contains('already_verified');
  }

  /// Returns true when an [ApiException] indicates unverified email during login.
  static bool isEmailUnverifiedError(ApiException e) {
    final code = (e.errorCode ?? '').toUpperCase();
    final msg = e.message.toLowerCase();
    return code == 'EMAIL_UNVERIFIED' ||
        msg.contains('verify your email') ||
        msg.contains('email is not verified') ||
        msg.contains('email not verified');
  }

  /// Detects an explicit backend denial directing admins to the web login.
  static bool isMobileAdminAccessError(ApiException error) {
    final code = (error.errorCode ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    const knownCodes = {
      'adminwebonly',
      'adminloginwebonly',
      'adminmobileloginblocked',
      'mobileadminlogindenied',
      'adminmobileaccessdenied',
      'adminmobileblocked',
    };
    final adminLoginDenied =
        code.contains('admin') &&
        code.contains('login') &&
        (code.contains('denied') ||
            code.contains('forbidden') ||
            code.contains('blocked') ||
            code.contains('notallowed'));
    if (knownCodes.contains(code) ||
        (code.contains('admin') &&
            (code.contains('mobile') || code.contains('web'))) ||
        adminLoginDenied) {
      return true;
    }

    final message = error.message.toLowerCase();
    final identifiesAdmin =
        message.contains('admin') || message.contains('administrator');
    final identifiesMobile =
        message.contains('mobile') || message.contains('app');
    final identifiesWebLogin =
        message.contains('web') ||
        message.contains('browser') ||
        message.contains('paidix.com/login');
    final identifiesLogin =
        message.contains('login') ||
        message.contains('sign in') ||
        message.contains('sign-in');
    return identifiesAdmin &&
        ((identifiesMobile && identifiesWebLogin) ||
            (identifiesLogin && identifiesWebLogin) ||
            message.contains('admin only'));
  }

  static const String _adminWebLoginMessage =
      'Admin accounts cannot sign in to the PaidiX mobile app. Use the PaidiX '
      'web admin login to continue.';

  static MobileAdminAccessException _adminAccessException({
    int statusCode = 403,
    String? message,
    String? errorCode,
  }) => MobileAdminAccessException(
    statusCode: statusCode,
    message: message == null || message.trim().isEmpty
        ? _adminWebLoginMessage
        : message,
    errorCode: errorCode ?? 'ADMIN_WEB_ONLY',
  );

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    return null;
  }

  static String? _stringValue(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static bool _isAdminValue(dynamic value) {
    if (value is List) return value.any(_isAdminValue);
    if (value is Map) {
      return value.entries.any((entry) {
        final key = '${entry.key}';
        final isRoleName = const {
          'name',
          'slug',
          'code',
          'value',
        }.contains(key.toLowerCase());
        return (_isAdminRoleKey(key) || isRoleName) &&
            _isAdminValue(entry.value);
      });
    }
    if (value is! String) return false;
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'admin' ||
        normalized == 'administrator' ||
        normalized.startsWith('admin') ||
        normalized.startsWith('superadmin') ||
        normalized.endsWith('admin') ||
        normalized.endsWith('administrator');
  }

  static bool _isAdminRoleKey(String key) => const {
    'role',
    'roles',
    'userrole',
    'accountrole',
    'usertype',
    'accounttype',
  }.contains(key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

  static bool _hasAdminIdentity(Map<String, dynamic> response) {
    final data = _asStringMap(response['data']) ?? const <String, dynamic>{};
    final user =
        _asStringMap(response['user']) ??
        _asStringMap(response['profile']) ??
        _asStringMap(data['user']) ??
        const <String, dynamic>{};
    final sources = [response, data, user];
    for (final source in sources) {
      for (final key in const [
        'role',
        'roles',
        'user_role',
        'userRole',
        'account_role',
        'accountRole',
        'user_type',
        'userType',
        'account_type',
        'accountType',
        'groups',
      ]) {
        if (_isAdminValue(source[key])) return true;
      }
      for (final key in const [
        'is_admin',
        'isAdmin',
        'is_staff',
        'isStaff',
        'is_superuser',
        'isSuperuser',
      ]) {
        final value = source[key];
        if (value == true ||
            value == 1 ||
            (value is String &&
                (value.toLowerCase() == 'true' || value == '1'))) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isAdminDeniedPayload(Map<String, dynamic> response) {
    final code =
        _stringValue(response, const ['errorCode', 'error_code', 'code']) ??
        _stringValue(_asStringMap(response['error']) ?? const {}, const [
          'errorCode',
          'error_code',
          'code',
        ]);
    final message =
        _stringValue(response, const ['message', 'detail']) ??
        _stringValue(_asStringMap(response['error']) ?? const {}, const [
          'message',
          'detail',
        ]);
    final error = response['error'];
    return isMobileAdminAccessError(
      ApiException(
        statusCode: 403,
        errorCode: code ?? (error is String ? error : null),
        message: message ?? (error is String ? error : ''),
      ),
    );
  }

  static String? _adminDeniedMessage(Map<String, dynamic> response) {
    final errorObject = _asStringMap(response['error']);
    final message =
        _stringValue(response, const ['message', 'detail']) ??
        _stringValue(errorObject ?? const {}, const ['message', 'detail']);
    if (message != null &&
        isMobileAdminAccessError(
          ApiException(statusCode: 403, message: message),
        )) {
      return message;
    }
    final errorText = response['error'];
    if (errorText is String &&
        isMobileAdminAccessError(
          ApiException(statusCode: 403, message: errorText),
        )) {
      return errorText;
    }
    return null;
  }

  static List<Map<String, dynamic>> _responseMaps(
    Map<String, dynamic> response,
  ) {
    final maps = <Map<String, dynamic>>[];
    const envelopeKeys = {
      'data',
      'results',
      'result',
      'records',
      'items',
      'submissions',
      'profiles',
      'profile',
      'user',
      'account',
      'customer',
      'kyc',
      'kyc_profile',
      'kycProfile',
      'review',
      'kyc_review',
      'kycReview',
      'review_details',
      'reviewDetails',
      'admin_review',
      'adminReview',
      'verification',
    };

    void collect(dynamic value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      final source = _asStringMap(value);
      if (source == null) return;
      maps.add(source);
      for (final key in envelopeKeys) {
        if (source.containsKey(key)) collect(source[key]);
      }
    }

    collect(response);
    return maps;
  }

  /// Reads only KYC-specific approval fields. `is_profile_complete` describes
  /// profile/onboarding completion and is never accepted as KYC approval.
  static KycReviewStatus? _parseKycStatus(
    Map<String, dynamic> response, {
    bool allowGenericStatus = false,
  }) {
    final statusKeys = <String>[
      'kyc_status',
      'kycStatus',
      'verification_status',
      'verificationStatus',
      'identity_status',
      'identityStatus',
      'review_status',
      'reviewStatus',
      'kyc_review_status',
      'kycReviewStatus',
      if (allowGenericStatus) 'status',
    ];
    for (final source in _responseMaps(response)) {
      for (final key in statusKeys) {
        final value = source[key];
        if (value is! String || value.trim().isEmpty) continue;
        final status = _normalizeKycStatus(value);
        switch (status) {
          case 'approved':
          case 'verified':
          case 'accepted':
            return KycReviewStatus.verified;
          case 'pending':
          case 'review':
          case 'pendingreview':
          case 'awaitingreview':
          case 'underreview':
          case 'inreview':
          case 'submitted':
          case 'resubmitted':
            return KycReviewStatus.pendingReview;
          case 'awaitingcustomer':
          case 'awaitingcustomerreview':
          case 'awaitingcustomerresponse':
          case 'awaitingcustomerupdate':
          case 'awaitinguser':
          case 'awaitingupdate':
          case 'awaitingcustomeraction':
          case 'waitingforcustomer':
          case 'waitingoncustomer':
          case 'actionrequired':
          case 'customeractionrequired':
          case 'needsaction':
          case 'changesrequested':
          case 'returnedforcorrection':
          case 'returnedtocustomer':
          case 'objectionraised':
          case 'objectionsraised':
          case 'objection':
          case 'objections':
          case 'objectionpending':
          case 'needsupdate':
            return KycReviewStatus.awaitingCustomer;
          case 'rejected':
          case 'declined':
          case 'verificationrejected':
          case 'needsresubmission':
          case 'resubmissionrequired':
            return KycReviewStatus.rejected;
          case 'inprogress':
          case 'processing':
            return KycReviewStatus.inProgress;
          case 'draft':
          case 'notstarted':
          case 'incomplete':
            return KycReviewStatus.notStarted;
        }
      }
    }

    final verifiedKeys = <String>[
      'kyc_verified',
      'kycVerified',
      'is_kyc_verified',
      'isKycVerified',
      'identity_verified',
      'identityVerified',
      'is_identity_verified',
      'isIdentityVerified',
      if (allowGenericStatus) 'is_verified',
      if (allowGenericStatus) 'isVerified',
      if (allowGenericStatus) 'verified',
    ];
    for (final source in _responseMaps(response)) {
      for (final key in verifiedKeys) {
        final value = source[key];
        if (value == true ||
            (value is String && value.toLowerCase() == 'true')) {
          return KycReviewStatus.verified;
        }
        if (value == false ||
            (value is String && value.toLowerCase() == 'false')) {
          return KycReviewStatus.inProgress;
        }
      }
    }

    return null;
  }

  static String _normalizeKycStatus(String value) {
    var normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    // The API contract uses enum values such as KYC_PENDING and
    // KYC_RESUBMITTED. Treat these as their corresponding review states.
    if (normalized.startsWith('kyc')) {
      normalized = normalized.substring(3);
    }
    return normalized;
  }

  /// Keeps the server's distinct resubmission state for the profile UI while
  /// treating it as pending for access control.
  static bool _hasServerResubmittedKyc(Map<String, dynamic> response) {
    const statusKeys = [
      'kyc_status',
      'kycStatus',
      'verification_status',
      'verificationStatus',
      'identity_status',
      'identityStatus',
      'review_status',
      'reviewStatus',
      'kyc_review_status',
      'kycReviewStatus',
      'status',
    ];
    const resubmissionFlags = [
      'has_resubmitted_kyc',
      'hasResubmittedKyc',
      'kyc_resubmitted',
      'kycResubmitted',
      'is_kyc_resubmitted',
      'isKycResubmitted',
      'resubmission_pending',
      'resubmissionPending',
    ];

    for (final source in _responseMaps(response)) {
      for (final key in statusKeys) {
        final value = source[key];
        if (value is String && _normalizeKycStatus(value) == 'resubmitted') {
          return true;
        }
      }
      for (final key in resubmissionFlags) {
        final value = source[key];
        if (value == true ||
            (value is String && value.toLowerCase() == 'true')) {
          return true;
        }
      }
    }
    return false;
  }

  static const List<String> _avatarUrlKeys = [
    'profile_picture_url',
    'profilePictureUrl',
    'profile_picture',
    'profilePicture',
    'avatar_url',
    'avatarUrl',
    'avatar',
    'photo_url',
    'photoUrl',
  ];

  /// Extracts a normalized profile-picture URL from an auth/profile payload.
  String? extractAvatarUrl(Map<String, dynamic> response) =>
      _firstServerImageUrl(_responseMaps(response), _avatarUrlKeys);

  String? _firstServerImageUrl(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final raw = source[key];
        final value = raw is String
            ? raw.trim()
            : raw is Map
            ? _firstNonEmptyString(
                [raw.map((k, v) => MapEntry('$k', v))],
                const ['url', 'uri', 'path', 'file'],
              )
            : null;
        if (value != null && value.isNotEmpty) {
          return _client.resolveMediaUrl(value);
        }
      }
    }
    return null;
  }

  static bool? _readBoolean(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is bool) return value;
        if (value is String) {
          if (value.toLowerCase() == 'true' || value == '1') return true;
          if (value.toLowerCase() == 'false' || value == '0') return false;
        }
      }
    }
    return null;
  }

  static String? _firstNonEmptyString(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  /// Reads reviewer objections from the account response without exposing raw
  /// map/list serialization in the UI. `null` means the endpoint omitted the
  /// field; an empty list means the server explicitly cleared all objections.
  static List<String>? _firstKycObjections(List<Map<String, dynamic>> sources) {
    const keys = [
      'kyc_objections',
      'kycObjections',
      'objections',
      'review_objections',
      'reviewObjections',
      'kyc_objection_details',
      'kycObjectionDetails',
      'objection_details',
      'objectionDetails',
      'field_objections',
      'fieldObjections',
      'requested_changes',
      'requestedChanges',
      'objection_list',
      'objectionList',
      'kyc_objection',
      'kycObjection',
    ];
    const objectionFieldKeys = [
      'field',
      'field_name',
      'fieldName',
      'field_key',
      'fieldKey',
      'field_label',
      'fieldLabel',
      'document',
      'document_type',
      'documentType',
      'section',
      'target',
      'name',
    ];
    const objectionDetailKeys = [
      'reason',
      'comment',
      'message',
      'note',
      'description',
      'objection',
      'issue',
      'objection_text',
      'objectionText',
      'text',
      'value',
    ];

    for (final source in sources) {
      for (final key in keys) {
        if (!source.containsKey(key)) continue;
        final raw = source[key];
        if (raw == null) return const <String>[];
        if (raw is String) {
          final value = raw.trim();
          return value.isEmpty ? const <String>[] : [value];
        }
        final rawMap = _asStringMap(raw);
        final isSingleObjection =
            rawMap != null &&
            (objectionFieldKeys.any(rawMap.containsKey) ||
                objectionDetailKeys.any(rawMap.containsKey));
        final items = rawMap != null && isSingleObjection
            ? [rawMap]
            : rawMap != null
            ? rawMap.entries.map(
                (entry) => <String, dynamic>{
                  'field': entry.key,
                  if (entry.value is Map)
                    ...(entry.value as Map).map(
                      (key, value) => MapEntry('$key', value),
                    )
                  else
                    'reason': entry.value,
                },
              )
            : raw is Iterable
            ? raw
            : const <dynamic>[];

        final objections = <String>[];
        for (final item in items) {
          final formatted = _formatKycObjection(item);
          if (formatted != null && !objections.contains(formatted)) {
            objections.add(formatted);
          }
        }
        return objections;
      }
    }
    return null;
  }

  static String? _formatKycObjection(dynamic value) {
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is! Map) return null;

    final objection = value.map((key, value) => MapEntry('$key', value));
    const fieldKeys = [
      'field',
      'field_name',
      'fieldName',
      'field_key',
      'fieldKey',
      'field_label',
      'fieldLabel',
      'document',
      'document_type',
      'documentType',
      'section',
      'target',
      'name',
    ];
    const detailKeys = [
      'reason',
      'comment',
      'message',
      'note',
      'description',
      'objection',
      'issue',
      'objection_text',
      'objectionText',
      'text',
      'value',
    ];
    final field = _firstNonEmptyString([objection], fieldKeys);
    var detail = _firstNonEmptyString([objection], detailKeys);
    if (detail == null) {
      for (final nested in objection.values.whereType<Map>()) {
        final nestedMap = nested.map((key, value) => MapEntry('$key', value));
        detail = _firstNonEmptyString([nestedMap], detailKeys);
        if (detail != null) break;
      }
    }

    // Support compact payloads such as {"cnic_front": "Blurry"} as well as
    // structured records such as {"field": "cnic_front", "reason": "..."}.
    if (field == null && detail == null) {
      const fieldNames = {
        'selfie',
        'cnic_front',
        'cnic_back',
        'full_name',
        'phone',
        'cnic_number',
        'city',
        'address',
        'bank_account',
      };
      for (final entry in objection.entries) {
        if (!fieldNames.contains(entry.key.toLowerCase())) continue;
        final nested = entry.value;
        if (nested is String && nested.trim().isNotEmpty) {
          return '${_humanizeKycField(entry.key)}: ${nested.trim()}';
        }
        if (nested is Map) {
          final nestedMap = nested.map((key, value) => MapEntry('$key', value));
          detail = _firstNonEmptyString([nestedMap], detailKeys);
          if (detail != null) {
            return '${_humanizeKycField(entry.key)}: $detail';
          }
        }
      }
    }

    if (field == null) return detail;
    final label = _humanizeKycField(field);
    if (detail == null || detail.isEmpty) return label;
    return '$label: $detail';
  }

  static String _humanizeKycField(String field) {
    final normalized = field
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    const labels = {
      'selfie': 'Selfie',
      'selfie_photo': 'Selfie',
      'cnic_front': 'CNIC front',
      'cnic_back': 'CNIC back',
      'cnic_number': 'CNIC number',
      'full_name': 'Full name',
      'phone': 'Phone',
      'phone_number': 'Phone',
      'city': 'City',
      'address': 'Address',
      'bank_account': 'Bank account',
      'bank_details': 'Bank details',
    };
    final knownLabel = labels[normalized];
    if (knownLabel != null) return knownLabel;
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static double? _firstNumber(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  static int? _firstInteger(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) => _firstNumber(sources, keys)?.toInt();

  /// Posts to a public (unauthenticated) auth endpoint without Bearer header.
  Future<Map<String, dynamic>> _postPublic(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _client.post(path, body: body, includeAuth: false);
  }

  /// Executes `POST /auth/login/` with 404 fallback to `/auth/signin`.
  Future<Map<String, dynamic>> _postLogin(SignInRequest request) async {
    try {
      return await _postPublic('/auth/login/', body: request.toJson());
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return await _postPublic('/auth/signin', body: request.toJson());
      }
      rethrow;
    }
  }

  /// Handles a 401 EMAIL_UNVERIFIED login response by dispatching a fresh OTP
  /// or retrying login directly if the backend reports email already verified.
  Future<Map<String, dynamic>> _dispatchOtpOrRecoverVerifiedLogin(
    SignInRequest request,
    ApiException loginError,
  ) async {
    try {
      await _postPublic(
        '/auth/email/resend/',
        body: {
          'email': request.email.trim().toLowerCase(),
          'password': request.password,
        },
      );
    } on ApiException catch (resendErr) {
      if (isAlreadyVerifiedMessage(resendErr.message)) {
        try {
          return await _postLogin(request);
        } on ApiException catch (retryErr) {
          if (isEmailUnverifiedError(retryErr)) {
            throw ApiException(
              statusCode: retryErr.statusCode,
              message: '${resendErr.message} ${retryErr.message}'.trim(),
              errorCode: 'EMAIL_VERIFICATION_CONFLICT',
            );
          }
          rethrow;
        }
      }
      throw EmailUnverifiedException(
        message: loginError.message,
        otpSent: false,
        resendNotice: resendErr.message,
        statusCode: loginError.statusCode,
      );
    }

    throw EmailUnverifiedException(
      message: loginError.message,
      otpSent: true,
      statusCode: loginError.statusCode,
    );
  }

  /// Registers a new user account with the backend server.
  Future<AuthResult> signUp(SignUpRequest request) async {
    final now = DateTime.now();
    if (AppConfig.hasCustomBackend) {
      Map<String, dynamic> data;
      try {
        data = await _postPublic(
          '/auth/signup/request-otp/',
          body: request.toJson(),
        );
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          data = await _postPublic('/auth/signup', body: request.toJson());
        } else {
          rethrow;
        }
      }

      final access = (data['access'] ?? data['token']) as String? ?? '';
      final refresh = data['refresh'] as String? ?? '';
      if (access.isNotEmpty) {
        await _client.setAuthTokens(access: access, refresh: refresh);
      } else {
        // Clear any leftover token from an earlier account while awaiting OTP.
        await _client.clearSession();
      }

      final userData = data['user'] as Map<String, dynamic>? ?? {};
      final fullName =
          userData['full_name'] as String? ??
          userData['fullName'] as String? ??
          request.fullName;
      final profile = UserProfile(
        fullName: fullName,
        email: userData['email'] as String? ?? request.email,
        countryCode: '+92',
        phoneNumber: userData['phone'] as String? ?? (request.phone ?? ''),
        cnicNumber:
            userData['cnic_number'] as String? ??
            userData['cnicNumber'] as String? ??
            '',
        city: userData['city'] as String? ?? '',
        address: userData['address'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
        hasCompletedKyc: userData['hasCompletedKyc'] as bool? ?? false,
        kycStatus: KycReviewStatus.notStarted,
      );

      UserProfileRepository.instance.setActiveUser(profile);
      return AuthResult(profile: profile, token: access);
    }

    // Local offline storage fallback (when no custom backend URL is supplied)
    await Future.delayed(const Duration(milliseconds: 300));
    UserProfileRepository.instance.syncFromSignUp(
      fullName: request.fullName,
      email: request.email,
      countryCode: '+92',
      phoneNumber: request.phone ?? '',
      smsConsent: request.smsConsent,
    );
    final profile = UserProfileRepository.instance.profile;
    const sessionToken = 'local_session_token';
    await _client.setAuthToken(sessionToken);
    return AuthResult(profile: profile, token: sessionToken);
  }

  /// Authenticates an existing user account with the backend server.
  ///
  /// Flow (matching the API spec):
  ///  - 200 OK → email is already verified; stores JWT tokens directly and returns
  ///    [AuthResult] so caller routes straight to Dashboard/KYC with no OTP modal.
  ///  - 401 EMAIL_UNVERIFIED → attempts to dispatch a fresh 6-digit OTP via
  ///    `POST /auth/email/resend/`.
  ///    - If resend succeeds → throws [EmailUnverifiedException] with `otpSent: true`.
  ///    - If resend reports email is already verified → retries login once; if
  ///      login succeeds, signs the user in directly without showing any OTP modal.
  ///    - If resend fails (e.g. 429 rate limit) → throws [EmailUnverifiedException]
  ///      with `otpSent: false` and the exact server `resendNotice`.
  Future<AuthResult> signIn(SignInRequest request) async {
    final inputEmail = request.email.trim().toLowerCase();
    final now = DateTime.now();

    // Simulated error testing hooks
    if (inputEmail.startsWith('error') || inputEmail.startsWith('500')) {
      throw const ApiException(
        statusCode: 503,
        message: 'Unable to reach the core authentication and settlement cluster. Please retry or verify your network connection.',
        errorCode: 'ERR_AUTH_503_UNAVAILABLE',
      );
    }

    if (AppConfig.hasCustomBackend) {
      Map<String, dynamic> data;
      try {
        data = await _postLogin(request);
      } on ApiException catch (e) {
        if (isMobileAdminAccessError(e)) {
          await _client.clearSession();
          throw _adminAccessException(
            statusCode: e.statusCode,
            message: e.message,
            errorCode: e.errorCode,
          );
        } else if (e.statusCode == 401 && isEmailUnverifiedError(e)) {
          data = await _dispatchOtpOrRecoverVerifiedLogin(request, e);
        } else {
          rethrow;
        }
      }

      return _buildAuthResultFromLogin(data, inputEmail, now);
    }

    // Local / Offline fallback logic preserving persistent profiles
    await Future.delayed(const Duration(milliseconds: 300));
    final repo = UserProfileRepository.instance;
    final registered =
        await repo.findOrLoadUser(inputEmail) ?? repo.findUser(inputEmail);

    if (registered != null) {
      repo.setActiveUser(registered);
      const token = 'local_session_token';
      await _client.setAuthToken(token);
      return AuthResult(profile: registered, token: token);
    }

    final newUser = UserProfile(
      fullName: inputEmail.split('@').first,
      email: inputEmail,
      countryCode: '+92',
      phoneNumber: '',
      cnicNumber: '',
      city: '',
      address: '',
      createdAt: now,
      updatedAt: now,
      hasCompletedKyc: false,
      kycStatus: KycReviewStatus.notStarted,
    );
    repo.setActiveUser(newUser);
    const token = 'new_user_session_token';
    await _client.setAuthToken(token);
    return AuthResult(profile: newUser, token: token);
  }

  Future<AuthResult> _buildAuthResultFromLogin(
    Map<String, dynamic> data,
    String inputEmail,
    DateTime now,
  ) async {
    // The server is the source of truth for account roles. Enforce the mobile
    // restriction before storing any token or requesting the authenticated
    // profile endpoint.
    if (_hasAdminIdentity(data) || _isAdminDeniedPayload(data)) {
      await _client.clearSession();
      final error = _asStringMap(data['error']);
      throw _adminAccessException(
        message: _adminDeniedMessage(data),
        errorCode:
            _stringValue(data, const ['errorCode', 'error_code', 'code']) ??
            _stringValue(error ?? const {}, const [
              'errorCode',
              'error_code',
              'code',
            ]),
      );
    }

    final access = (data['access'] ?? data['token']) as String? ?? '';
    final refresh = data['refresh'] as String? ?? '';
    if (access.isNotEmpty) {
      await _client.setAuthTokens(access: access, refresh: refresh);
    }
    clearServerKycStatus();

    final userData = _asStringMap(data['user']) ?? {};
    final userRepository = UserProfileRepository.instance;
    final activeProfile = userRepository.profile;
    final savedProfile = activeProfile.email.trim().toLowerCase() == inputEmail
        ? activeProfile
        : await userRepository.findOrLoadUser(inputEmail);

    Map<String, dynamic> currentUserData = {};
    try {
      currentUserData = await _client.get('/auth/me/');
    } catch (_) {
      // The login response and same-user local record remain usable if profile
      // enrichment is temporarily unavailable.
    }

    Map<String, dynamic> kycProfileData = {};
    try {
      // This endpoint reports KYC review state. It is intentionally queried on
      // every live sign-in so a stale local profile cannot hide onboarding.
      kycProfileData = await _client.get('/accounts/profile/');
    } catch (_) {
      // Missing/unavailable status is treated as unverified below.
    }

    final loginKycStatus = _parseKycStatus({'user': userData, ...data});
    final currentUserKycStatus = _parseKycStatus(currentUserData);
    final profileKycStatus = _parseKycStatus(
      kycProfileData,
      allowGenericStatus: true,
    );
    final remoteSources = [
      ..._responseMaps(kycProfileData),
      ..._responseMaps(currentUserData),
      ..._responseMaps(data),
    ];
    const submittedKeys = [
      'has_completed_kyc',
      'hasCompletedKyc',
      'kyc_submitted',
      'kycSubmitted',
      'documents_submitted',
      'documentsSubmitted',
    ];
    final serverSubmissionFlag = _readBoolean(remoteSources, submittedKeys);
    final nonApprovalServerStatus = [currentUserKycStatus, loginKycStatus]
        .whereType<KycReviewStatus>()
        .firstWhere(
          (status) => status != KycReviewStatus.verified,
          orElse: () => KycReviewStatus.notStarted,
        );
    final hasNonApprovalServerStatus =
        currentUserKycStatus != null &&
            currentUserKycStatus != KycReviewStatus.verified ||
        loginKycStatus != null && loginKycStatus != KycReviewStatus.verified;
    final serverKycStatus =
        profileKycStatus ??
        (hasNonApprovalServerStatus
            ? nonApprovalServerStatus
            : serverSubmissionFlag == true
            ? KycReviewStatus.pendingReview
            : null);
    final savedKycStatus = savedProfile?.kycStatus;

    // Cached verification is never sufficient to retire onboarding. If the
    // server has no status, a previously verified local record falls back to
    // Pending Review until a backend approval is confirmed again.
    final kycStatus =
        serverKycStatus ??
        (savedKycStatus == KycReviewStatus.verified
            ? KycReviewStatus.pendingReview
            : savedKycStatus ?? KycReviewStatus.notStarted);

    final hasCompletedKyc = serverKycStatus == null
        ? savedProfile?.hasCompletedKyc ?? false
        : (kycStatus == KycReviewStatus.verified ||
              kycStatus == KycReviewStatus.pendingReview ||
              kycStatus.requiresCustomerAction ||
              (serverSubmissionFlag ?? false));

    final serverName = _firstNonEmptyString(remoteSources, const [
      'full_name',
      'fullName',
      'name',
    ]);
    final serverEmail =
        _firstNonEmptyString(remoteSources, const ['email']) ?? inputEmail;
    final serverPhone = _firstNonEmptyString(remoteSources, const [
      'phone',
      'phone_number',
      'phoneNumber',
    ]);
    final serverCnic = _firstNonEmptyString(remoteSources, const [
      'cnic_number',
      'cnicNumber',
      'national_id',
    ]);
    final serverCity = _firstNonEmptyString(remoteSources, const ['city']);
    final serverAddress = _firstNonEmptyString(remoteSources, const [
      'address',
    ]);
    final selfieUrl = _firstServerImageUrl(remoteSources, const [
      'selfie_url',
      'selfieUrl',
      'selfie_image',
      'selfie_image_url',
      'selfie',
    ]);
    final cnicFrontUrl = _firstServerImageUrl(remoteSources, const [
      'cnic_front_url',
      'cnicFrontUrl',
      'cnic_front_image',
      'cnic_front_image_url',
      'cnic_front',
    ]);
    final cnicBackUrl = _firstServerImageUrl(remoteSources, const [
      'cnic_back_url',
      'cnicBackUrl',
      'cnic_back_image',
      'cnic_back_image_url',
      'cnic_back',
    ]);
    final serverAvatarUrl = _firstServerImageUrl(remoteSources, _avatarUrlKeys);
    final remoteAvatarChanged =
        serverAvatarUrl != null &&
        savedProfile?.avatarUrl != null &&
        serverAvatarUrl != savedProfile!.avatarUrl;
    final hasResubmittedKyc =
        kycStatus == KycReviewStatus.pendingReview &&
        (_hasServerResubmittedKyc(kycProfileData) ||
            _hasServerResubmittedKyc(currentUserData) ||
            _hasServerResubmittedKyc(data));
    final resubmittedAtValue = _firstNonEmptyString(remoteSources, const [
      'kyc_last_resubmit_at',
      'kycLastResubmitAt',
      'kyc_resubmitted_at',
      'resubmitted_at',
      'kyc_submitted_at',
      'submitted_at',
    ]);
    final kycResubmittedAt = !hasResubmittedKyc
        ? null
        : (resubmittedAtValue == null
                  ? null
                  : DateTime.tryParse(resubmittedAtValue)) ??
              savedProfile?.kycResubmittedAt;
    final preservesCurrentFeedback = savedProfile?.kycStatus == kycStatus;
    final rejectionReason = kycStatus.requiresCustomerAction
        ? (_firstNonEmptyString(remoteSources, _kycRejectionReasonKeys) ??
              (preservesCurrentFeedback
                  ? savedProfile?.kycRejectionReason
                  : null))
        : null;
    final remoteObjections = _firstKycObjections(remoteSources);
    final kycObjections = kycStatus.requiresCustomerAction
        ? (remoteObjections ??
              (preservesCurrentFeedback
                  ? savedProfile?.kycObjections ?? const <String>[]
                  : const <String>[]))
        : const <String>[];
    final reviewedAtValue = _firstNonEmptyString(remoteSources, const [
      'kyc_reviewed_at',
      'reviewed_at',
      'reviewedAt',
      'last_reviewed_at',
      'rejected_at',
      'rejection_date',
      'reviewed_on',
    ]);
    final reviewedAt = reviewedAtValue == null
        ? savedProfile?.kycReviewedAt
        : DateTime.tryParse(reviewedAtValue) ?? savedProfile?.kycReviewedAt;

    final profile = UserProfile(
      fullName:
          serverName ??
          (savedProfile?.fullName.isNotEmpty == true
              ? savedProfile!.fullName
              : inputEmail.split('@').first),
      email: serverEmail,
      countryCode:
          _firstNonEmptyString(remoteSources, const [
            'country_code',
            'countryCode',
          ]) ??
          savedProfile?.countryCode ??
          '+92',
      phoneNumber: serverPhone ?? savedProfile?.phoneNumber ?? '',
      cnicNumber: serverCnic ?? savedProfile?.cnicNumber ?? '',
      city: serverCity ?? savedProfile?.city ?? '',
      address: serverAddress ?? savedProfile?.address ?? '',
      createdAt: savedProfile?.createdAt ?? now,
      updatedAt: now,
      hasCompletedKyc: hasCompletedKyc,
      kycStatus: kycStatus,
      hasResubmittedKyc: hasResubmittedKyc,
      kycResubmittedAt: kycResubmittedAt,
      smsConsent: savedProfile?.smsConsent ?? true,
      selfieBytes: savedProfile?.selfieBytes,
      selfieFilePath: savedProfile?.selfieFilePath,
      selfieUrl: selfieUrl ?? savedProfile?.selfieUrl,
      cnicFrontBytes: savedProfile?.cnicFrontBytes,
      cnicFrontFilePath: savedProfile?.cnicFrontFilePath,
      cnicFrontUrl: cnicFrontUrl ?? savedProfile?.cnicFrontUrl,
      cnicBackBytes: savedProfile?.cnicBackBytes,
      cnicBackFilePath: savedProfile?.cnicBackFilePath,
      cnicBackUrl: cnicBackUrl ?? savedProfile?.cnicBackUrl,
      avatarBytes: remoteAvatarChanged ? null : savedProfile?.avatarBytes,
      avatarFilePath: remoteAvatarChanged ? null : savedProfile?.avatarFilePath,
      avatarUrl: serverAvatarUrl ?? savedProfile?.avatarUrl,
      bankName: savedProfile?.bankName,
      bankAccountNumber: savedProfile?.bankAccountNumber,
      bankIban: savedProfile?.bankIban,
      bankBeneficiary: savedProfile?.bankBeneficiary,
      kycRejectionReason: rejectionReason,
      kycObjections: kycObjections,
      kycReviewedAt: reviewedAt,
      ratingScore:
          _firstInteger(remoteSources, const [
            'rating_score',
            'ratingScore',
            'customer_score',
            'customerScore',
            'score',
          ]) ??
          savedProfile?.ratingScore,
      ratingTier:
          _firstNonEmptyString(remoteSources, const [
            'rating_tier',
            'ratingTier',
            'customer_tier',
            'customerTier',
          ]) ??
          savedProfile?.ratingTier,
      ratingGrade:
          _firstNonEmptyString(remoteSources, const [
            'rating_grade',
            'ratingGrade',
            'score_grade',
            'scoreGrade',
            'grade',
          ]) ??
          savedProfile?.ratingGrade,
      completedCount:
          _firstInteger(remoteSources, const [
            'completed_count',
            'completedCount',
            'completed_transactions',
            'completedTransactions',
            'rating_completed_count',
          ]) ??
          savedProfile?.completedCount,
      rejectedCount:
          _firstInteger(remoteSources, const [
            'rejected_count',
            'rejectedCount',
            'rating_rejected_count',
          ]) ??
          savedProfile?.rejectedCount,
      totalVolumePkr:
          _firstNumber(remoteSources, const [
            'total_volume_pkr',
            'totalVolumePkr',
            'rating_total_volume_pkr',
          ]) ??
          savedProfile?.totalVolumePkr,
    );

    userRepository.setActiveUser(profile);
    if (serverKycStatus != null) {
      _recordServerKycStatus(serverEmail, serverKycStatus);
    }
    unawaited(
      KycRepository.instance
          .fetchBankAccounts(email: serverEmail)
          .catchError((_) => <BankAccountItem>[]),
    );
    return AuthResult(profile: profile, token: access);
  }

  /// Verifies an OTP code for email verification (POST /auth/email/verify/)
  ///
  /// Returns true on success. Also returns true when the backend reports
  /// "Email is already verified" — this means the user's email is confirmed,
  /// and we should proceed straight to sign-in.
  Future<bool> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final cleanCode = code.replaceAll(RegExp(r'\D'), '');
    if (AppConfig.hasCustomBackend) {
      try {
        await _postPublic(
          '/auth/email/verify/',
          body: {
            'email': email.trim().toLowerCase(),
            'code': cleanCode.isNotEmpty ? cleanCode : code.trim(),
          },
        );
      } on ApiException catch (e) {
        if (isAlreadyVerifiedMessage(e.message)) {
          return true;
        }
        rethrow;
      }
      return true;
    }
    return true;
  }

  /// Resends a 6-digit email verification OTP (POST /auth/email/resend/)
  ///
  /// Returns true only when the server actually sent a new OTP code.
  /// Throws [EmailAlreadyVerifiedException] when the server reports the email
  /// is already verified so the caller proceeds directly to sign-in instead of
  /// pretending an email was dispatched.
  Future<bool> resendEmailOtp({
    required String email,
    required String password,
  }) async {
    if (AppConfig.hasCustomBackend) {
      try {
        await _postPublic(
          '/auth/email/resend/',
          body: {'email': email.trim().toLowerCase(), 'password': password},
        );
      } on ApiException catch (e) {
        if (isAlreadyVerifiedMessage(e.message)) {
          throw EmailAlreadyVerifiedException(
            statusCode: e.statusCode,
            message: e.message,
          );
        }
        rethrow;
      }
      return true;
    }
    return true;
  }

  /// Fetches the authenticated user profile and flags from backend (GET /auth/me/)
  Future<Map<String, dynamic>> fetchCurrentUserProfile() async {
    if (AppConfig.hasCustomBackend) {
      final data = await _client.get('/auth/me/');
      final current = UserProfileRepository.instance.profile;
      if (current.email.isNotEmpty) {
        final serverAvatarUrl = extractAvatarUrl(data);
        if (serverAvatarUrl != null && serverAvatarUrl != current.avatarUrl) {
          UserProfileRepository.instance.updateProfile(
            avatarUrl: serverAvatarUrl,
            clearAvatarBytes: current.avatarUrl != null,
          );
        }
      }
      return data;
    }
    return {};
  }

  /// Polls the authenticated KYC profile and applies server review changes.
  /// Returns null when the server did not provide a recognizable KYC status.
  Future<KycReviewStatus?> refreshKycReviewStatus() {
    if (!AppConfig.hasCustomBackend) {
      return Future<KycReviewStatus?>.value(null);
    }
    final inFlight = _kycStatusRefreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _refreshKycReviewStatus();
    _kycStatusRefreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_kycStatusRefreshInFlight, refresh)) {
        _kycStatusRefreshInFlight = null;
      }
    });
  }

  Future<KycReviewStatus?> _refreshKycReviewStatus() async {
    final requestStartedAt = DateTime.now();
    final response = await _client.get('/accounts/profile/');
    final status = _parseKycStatus(response, allowGenericStatus: true);
    final profileRepository = UserProfileRepository.instance;
    final sources = _responseMaps(response);
    final current = profileRepository.profile;
    final ratingScore = _firstInteger(sources, const [
      'rating_score',
      'ratingScore',
      'customer_score',
      'customerScore',
      'score',
    ]);
    final ratingTier = _firstNonEmptyString(sources, const [
      'rating_tier',
      'ratingTier',
      'customer_tier',
      'customerTier',
    ]);
    final ratingGrade = _firstNonEmptyString(sources, const [
      'rating_grade',
      'ratingGrade',
      'score_grade',
      'scoreGrade',
      'grade',
    ]);
    final completedCount = _firstInteger(sources, const [
      'completed_count',
      'completedCount',
      'completed_transactions',
      'completedTransactions',
      'rating_completed_count',
    ]);
    final rejectedCount = _firstInteger(sources, const [
      'rejected_count',
      'rejectedCount',
      'rating_rejected_count',
    ]);
    final totalVolumePkr = _firstNumber(sources, const [
      'total_volume_pkr',
      'totalVolumePkr',
      'rating_total_volume_pkr',
    ]);
    final scoreChanged =
        (ratingScore != null && ratingScore != current.ratingScore) ||
        (ratingTier != null && ratingTier != current.ratingTier) ||
        (ratingGrade != null && ratingGrade != current.ratingGrade) ||
        (completedCount != null && completedCount != current.completedCount) ||
        (rejectedCount != null && rejectedCount != current.rejectedCount) ||
        (totalVolumePkr != null && totalVolumePkr != current.totalVolumePkr);

    if (status == null) {
      if (scoreChanged) {
        profileRepository.setActiveUser(
          current.copyWith(
            ratingScore: ratingScore,
            ratingTier: ratingTier,
            ratingGrade: ratingGrade,
            completedCount: completedCount,
            rejectedCount: rejectedCount,
            totalVolumePkr: totalVolumePkr,
          ),
        );
      }
      return null;
    }

    // A poll that began before the multipart upload completed can return an
    // older rejection after the local profile has already moved to review.
    // Ignore that one in-flight snapshot; the next poll fetches a fresh state.
    final submissionCompletedDuringPoll =
        current.hasResubmittedKyc &&
        current.kycResubmittedAt != null &&
        current.kycResubmittedAt!.isAfter(requestStartedAt);
    if (submissionCompletedDuringPoll) {
      if (scoreChanged) {
        profileRepository.setActiveUser(
          current.copyWith(
            ratingScore: ratingScore,
            ratingTier: ratingTier,
            ratingGrade: ratingGrade,
            completedCount: completedCount,
            rejectedCount: rejectedCount,
            totalVolumePkr: totalVolumePkr,
          ),
        );
      }
      return current.kycStatus;
    }

    final serverReportsResubmission = _hasServerResubmittedKyc(response);
    final reason = _firstNonEmptyString(sources, _kycRejectionReasonKeys);
    final objections = _firstKycObjections(sources);
    final reviewedAtValue = _firstNonEmptyString(sources, const [
      'kyc_reviewed_at',
      'reviewed_at',
      'reviewedAt',
      'last_reviewed_at',
      'rejected_at',
      'rejection_date',
      'reviewed_on',
    ]);
    final serverReviewedAt = reviewedAtValue == null
        ? null
        : DateTime.tryParse(reviewedAtValue);
    final latestResubmissionAt = current.kycResubmittedAt;
    if (status.requiresCustomerAction &&
        current.hasResubmittedKyc &&
        latestResubmissionAt != null &&
        serverReviewedAt != null &&
        !serverReviewedAt.isAfter(latestResubmissionAt)) {
      // The review timestamp belongs to the rejection that was already fixed.
      // Keep the accepted resubmission visible until a newer server review
      // arrives.
      return current.kycStatus;
    }
    final reviewedAt = reviewedAtValue == null
        ? current.kycReviewedAt
        : serverReviewedAt ?? current.kycReviewedAt;
    final preservesCurrentFeedback = status == current.kycStatus;
    final nextReason = status.requiresCustomerAction
        ? reason ??
              (preservesCurrentFeedback ? current.kycRejectionReason : null)
        : null;
    final nextObjections = status.requiresCustomerAction
        ? objections ??
              (preservesCurrentFeedback
                  ? current.kycObjections
                  : const <String>[])
        : const <String>[];
    final hasResubmittedKyc =
        status == KycReviewStatus.pendingReview &&
        (serverReportsResubmission || current.hasResubmittedKyc);
    final resubmittedAtValue = _firstNonEmptyString(sources, const [
      'kyc_last_resubmit_at',
      'kycLastResubmitAt',
      'kyc_resubmitted_at',
      'resubmitted_at',
      'kyc_submitted_at',
      'submitted_at',
    ]);
    final kycResubmittedAt = !hasResubmittedKyc
        ? null
        : (resubmittedAtValue == null
                  ? null
                  : DateTime.tryParse(resubmittedAtValue)) ??
              current.kycResubmittedAt ??
              DateTime.now();
    final selfieUrl = _firstServerImageUrl(sources, const [
      'selfie_url',
      'selfieUrl',
      'selfie_image',
      'selfie_image_url',
      'selfie',
    ]);
    final cnicFrontUrl = _firstServerImageUrl(sources, const [
      'cnic_front_url',
      'cnicFrontUrl',
      'cnic_front_image',
      'cnic_front_image_url',
      'cnic_front',
    ]);
    final cnicBackUrl = _firstServerImageUrl(sources, const [
      'cnic_back_url',
      'cnicBackUrl',
      'cnic_back_image',
      'cnic_back_image_url',
      'cnic_back',
    ]);

    final effectiveEmail = current.email.isNotEmpty
        ? current.email
        : (_firstNonEmptyString(sources, const ['user_email', 'email']) ?? '');
    _recordServerKycStatus(effectiveEmail, status);

    final changed =
        status != current.kycStatus ||
        hasResubmittedKyc != current.hasResubmittedKyc ||
        kycResubmittedAt != current.kycResubmittedAt ||
        nextReason != current.kycRejectionReason ||
        !_sameStrings(nextObjections, current.kycObjections) ||
        reviewedAt != current.kycReviewedAt ||
        (selfieUrl != null && selfieUrl != current.selfieUrl) ||
        (cnicFrontUrl != null && cnicFrontUrl != current.cnicFrontUrl) ||
        (cnicBackUrl != null && cnicBackUrl != current.cnicBackUrl) ||
        scoreChanged;
    if (!changed) return status;

    final updated = current.copyWith(
      kycStatus: status,
      hasCompletedKyc: status != KycReviewStatus.notStarted,
      hasResubmittedKyc: hasResubmittedKyc,
      kycResubmittedAt: kycResubmittedAt,
      clearKycResubmittedAt: !hasResubmittedKyc,
      selfieUrl: selfieUrl ?? current.selfieUrl,
      cnicFrontUrl: cnicFrontUrl ?? current.cnicFrontUrl,
      cnicBackUrl: cnicBackUrl ?? current.cnicBackUrl,
      updatedAt: DateTime.now(),
      kycRejectionReason: nextReason,
      kycObjections: nextObjections,
      kycReviewedAt: reviewedAt,
      clearRejection: !status.requiresCustomerAction,
      ratingScore: ratingScore ?? current.ratingScore,
      ratingTier: ratingTier ?? current.ratingTier,
      ratingGrade: ratingGrade ?? current.ratingGrade,
      completedCount: completedCount ?? current.completedCount,
      rejectedCount: rejectedCount ?? current.rejectedCount,
      totalVolumePkr: totalVolumePkr ?? current.totalVolumePkr,
    );
    UserProfileRepository.instance.setActiveUser(updated);
    return status;
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// Updates personal profile details or avatar (PATCH /auth/me/).
  Future<Map<String, dynamic>> updateCurrentUserProfile({
    String? fullName,
    String? phone,
    List<int>? profilePictureBytes,
    String? fileName,
    bool clearProfilePicture = false,
  }) async {
    if (!AppConfig.hasCustomBackend) {
      return {};
    }

    late final Map<String, dynamic> response;
    if (profilePictureBytes != null) {
      final safeBytes = Uint8List.fromList(profilePictureBytes);
      KycImageValidation.validateMaxFileSize(
        safeBytes,
        documentLabel: 'Profile picture',
      );
      var ext = 'png';
      try {
        ext = KycImageValidation.extensionFor(safeBytes);
      } catch (_) {}
      final effectiveName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : 'avatar.$ext';
      final fields = <String, String>{'full_name': ?fullName, 'phone': ?phone};
      List<http.MultipartFile> buildFiles() => [
        http.MultipartFile.fromBytes(
          'profile_picture',
          safeBytes,
          filename: effectiveName,
        ),
      ];
      try {
        response = await _client.patchMultipart(
          '/auth/me/',
          fields: fields,
          filesBuilder: buildFiles,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 405 || e.statusCode == 501) {
          response = await _client.postMultipart(
            '/auth/me/',
            fields: fields,
            filesBuilder: buildFiles,
          );
        } else {
          rethrow;
        }
      }

      final serverAvatarUrl = extractAvatarUrl(response);
      if (UserProfileRepository.instance.profile.email.isNotEmpty) {
        UserProfileRepository.instance.updateProfile(
          fullName: fullName,
          phoneNumber: phone,
          avatarBytes: safeBytes,
          avatarUrl: serverAvatarUrl,
        );
      }
      return response;
    } else {
      final body = <String, dynamic>{
        'full_name': ?fullName,
        'phone': ?phone,
        if (clearProfilePicture) 'profile_picture': null,
      };
      response = await _client.patch('/auth/me/', body: body);
      final serverAvatarUrl = extractAvatarUrl(response);
      if (UserProfileRepository.instance.profile.email.isNotEmpty) {
        UserProfileRepository.instance.updateProfile(
          fullName: fullName,
          phoneNumber: phone,
          avatarUrl: serverAvatarUrl,
          clearAvatar: clearProfilePicture,
        );
      }
      return response;
    }
  }

  /// Requests a password reset OTP code (POST /auth/forgot-password/request-otp/)
  Future<bool> requestPasswordResetOtp({required String email}) async {
    if (AppConfig.hasCustomBackend) {
      await _postPublic(
        '/auth/forgot-password/request-otp/',
        body: {'email': email.trim().toLowerCase()},
      );
      return true;
    }
    return true;
  }

  /// Resets user password using the 6-digit OTP (POST /auth/forgot-password/reset/)
  Future<bool> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (AppConfig.hasCustomBackend) {
      await _postPublic(
        '/auth/forgot-password/reset/',
        body: {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'new_password': newPassword,
        },
      );
      return true;
    }
    return true;
  }

  /// Updates account password for an authenticated user (POST /auth/change-password/)
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (AppConfig.hasCustomBackend) {
      await _client.post(
        '/auth/change-password/',
        body: {'old_password': oldPassword, 'new_password': newPassword},
      );
      return true;
    }
    return true;
  }

  /// Checks if Payments PIN is configured (GET /auth/payments-pin/)
  Future<bool> checkPaymentsPinStatus() async {
    if (AppConfig.hasCustomBackend) {
      // These checks are independent reads. Run them concurrently to avoid
      // adding the /auth/me/ round trip to the PIN-status response time.
      final results = await Future.wait<Object>([
        _requireVerifiedEmailForPaymentsPin().then<Object>((_) => true),
        _client.get('/auth/payments-pin/'),
      ]);
      final res = results[1] as Map<String, dynamic>;
      return res['is_set'] == true;
    }
    return false;
  }

  /// Sets initial Payments PIN (POST /auth/payments-pin/)
  Future<bool> setPaymentsPin({required String pin}) async {
    if (AppConfig.hasCustomBackend) {
      await _requireVerifiedEmailForPaymentsPin();
      await _client.post('/auth/payments-pin/', body: {'pin': pin});
      return true;
    }
    return true;
  }

  /// Updates existing Payments PIN (POST /auth/payments-pin/)
  Future<bool> updatePaymentsPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (AppConfig.hasCustomBackend) {
      await _requireVerifiedEmailForPaymentsPin();
      await _client.post(
        '/auth/payments-pin/',
        body: {'current_pin': currentPin, 'pin': newPin},
      );
      return true;
    }
    return true;
  }

  /// Removes Payments PIN (DELETE /auth/payments-pin/)
  Future<bool> removePaymentsPin({required String currentPin}) async {
    if (AppConfig.hasCustomBackend) {
      await _requireVerifiedEmailForPaymentsPin();
      await _client.delete(
        '/auth/payments-pin/',
        body: {'current_pin': currentPin},
      );
      return true;
    }
    return true;
  }

  /// Verifies Payments PIN before sensitive operations (POST /auth/payments-pin/verify/)
  Future<bool> verifyPaymentsPin({required String pin}) async {
    if (AppConfig.hasCustomBackend) {
      await _requireVerifiedEmailForPaymentsPin();
      final res = await _client.post(
        '/auth/payments-pin/verify/',
        body: {'pin': pin},
      );
      return res['ok'] == true;
    }
    return true;
  }

  /// Requests a fresh temporary Payments PIN by email
  /// (POST /auth/payments-pin/forgot/). The backend checks that [email] matches
  /// the authenticated account and applies its own reset rate limit.
  Future<String> requestPaymentsPinReset({required String email}) async {
    if (!AppConfig.hasCustomBackend) {
      throw const ApiException(
        statusCode: 501,
        message: 'Payments PIN recovery requires a server connection.',
        errorCode: 'PIN_RECOVERY_UNAVAILABLE',
      );
    }

    await _requireVerifiedEmailForPaymentsPin();
    final response = await _client.post(
      '/auth/payments-pin/forgot/',
      body: {'email': email.trim().toLowerCase()},
    );
    final detail = response['detail'] ?? response['message'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    return 'A new Payments PIN has been sent to your registered email.';
  }

  /// PIN operations are available only for authenticated, email-verified users.
  /// The backend remains authoritative and must enforce this rule as well.
  Future<void> _requireVerifiedEmailForPaymentsPin() async {
    final profile = await _client.get('/auth/me/');
    final emailVerified = _readBoolean(_responseMaps(profile), const [
      'email_verified',
      'emailVerified',
      'is_email_verified',
    ]);
    if (emailVerified != true) {
      throw const ApiException(
        statusCode: 403,
        message: 'Verify your account email before using a Payments PIN.',
        errorCode: 'EMAIL_UNVERIFIED',
      );
    }
  }

  /// Terminates the active session, revokes refresh token on server, and clears secure storage.
  Future<void> signOut() async {
    if (AppConfig.hasCustomBackend) {
      try {
        final refresh = _client.refreshToken;
        if (refresh != null && refresh.isNotEmpty) {
          await _client.post('/auth/logout/', body: {'refresh': refresh});
        }
      } catch (_) {
        // Non-blocking logout network error
      }
    }
    clearServerKycStatus();
    await _client.clearSession();
  }
}
