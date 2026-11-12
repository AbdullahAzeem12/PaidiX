/// Repository managing KYC document and identity submission to the backend.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/bank_account_validator.dart';
import '../../../core/utils/cnic_formatter.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/bank_account_item.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/kyc_models.dart';
import 'kyc_image_validation.dart';

class KycRepository {
  KycRepository._();
  static final KycRepository instance = KycRepository._();

  final ApiClient _client = ApiClient.instance;

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  /// Flattens the profile/list response envelopes used by the accounts API.
  /// In particular, DRF may return a list of customer records under `data`.
  static List<Map<String, dynamic>> _responseMaps(dynamic response) {
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
      'verification',
    };

    void collectWithParent(dynamic value, Map<String, dynamic> inherited) {
      if (value is List) {
        for (final item in value) {
          collectWithParent(item, inherited);
        }
        return;
      }
      final map = _asStringMap(value);
      if (map == null) return;
      final combined = <String, dynamic>{...inherited, ...map};
      maps.add(combined);
      final inheritedForChildren = Map<String, dynamic>.from(combined)
        ..removeWhere((key, _) => envelopeKeys.contains(key));
      for (final key in envelopeKeys) {
        if (map.containsKey(key)) {
          collectWithParent(map[key], inheritedForChildren);
        }
      }
    }

    collectWithParent(response, const <String, dynamic>{});
    return maps;
  }

  static String? _firstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _normalizeDigits(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static String _serverPhone({
    required String countryCode,
    required String phoneNumber,
  }) {
    final rawPhone = phoneNumber.trim();
    var phoneDigits = _normalizeDigits(rawPhone);
    if (phoneDigits.isEmpty) return '';

    if (rawPhone.startsWith('+')) {
      if (phoneDigits.startsWith('920') && phoneDigits.length >= 13) {
        phoneDigits = '92${phoneDigits.substring(3)}';
      }
      return '+$phoneDigits';
    }

    final countryDigits = _normalizeDigits(countryCode);
    if (countryDigits == '92' &&
        phoneDigits.startsWith('0') &&
        phoneDigits.length >= 10) {
      phoneDigits = phoneDigits.substring(1);
    }
    if (countryDigits.isNotEmpty && phoneDigits.startsWith(countryDigits)) {
      return '+$phoneDigits';
    }
    if (countryDigits.isNotEmpty) return '+$countryDigits$phoneDigits';
    return rawPhone;
  }

  static String _serverCnic(String cnicNumber) {
    final trimmed = cnicNumber.trim();
    final digits = CnicValidator.clean(trimmed);
    if (digits.length == 13) {
      return CnicValidator.format(digits);
    }
    return trimmed;
  }

  static String _validateUploadImage(
    Uint8List bytes, {
    required String documentLabel,
    required String errorCode,
  }) {
    try {
      return KycImageValidation.validateForUpload(
        bytes,
        documentLabel: documentLabel,
      );
    } on FormatException catch (e) {
      throw ApiException(
        statusCode: 422,
        message: e.message,
        errorCode: errorCode,
      );
    }
  }

  static DateTime? parseResubmittedAt(Map<String, dynamic> response) {
    for (final map in _responseMaps(response)) {
      final raw = _firstString(map, const [
        'kyc_last_resubmit_at',
        'kycLastResubmitAt',
        'kyc_resubmitted_at',
        'resubmitted_at',
        'updated_at',
      ]);
      if (raw != null) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? parseDocumentUrl(Map<String, dynamic> response, List<String> keys) {
    for (final map in _responseMaps(response)) {
      final raw = _firstString(map, keys);
      if (raw != null) {
        return _client.resolveMediaUrl(raw);
      }
    }
    return null;
  }

  static Map<String, String> _buildPatchResubmissionFields({
    required String fullName,
    required String countryCode,
    required String phoneNumber,
    required String cnicNumber,
    required String city,
    required String address,
  }) {
    final serverPhone = _serverPhone(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    );
    final serverCnic = _serverCnic(cnicNumber);
    // Do NOT send `kyc_status` or `is_resubmission`: PATCH /accounts/profile/
    // automatically transitions the backend status to `"resubmitted"`.
    return <String, String>{
      if (fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
      if (serverPhone.isNotEmpty) 'phone': serverPhone,
      if (serverCnic.isNotEmpty) 'cnic_number': serverCnic,
      if (city.trim().isNotEmpty) 'city': city.trim(),
      if (address.trim().isNotEmpty) 'address': address.trim(),
    };
  }

  static String _normalizeStatus(String value) {
    var status = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (status.startsWith('kyc')) status = status.substring(3);
    return status;
  }

  static bool _recordConfirmsResubmission(
    Map<String, dynamic> record, {
    required UserProfile profile,
  }) {
    final status = _firstString(record, const [
      'kyc_status',
      'kycStatus',
      'verification_status',
      'review_status',
      'status',
    ]);
    if (status == null || _normalizeStatus(status) != 'resubmitted') {
      return false;
    }

    final email = _firstString(record, const ['user_email', 'email']);
    // `/accounts/profile/` is authenticated and user-scoped. Some deployments
    // return only a status envelope after upload; if an email is included,
    // require it to match before treating that status as confirmation.
    return email == null ||
        profile.email.trim().isEmpty ||
        email.trim().toLowerCase() == profile.email.trim().toLowerCase();
  }

  /// Confirms that the server has moved this authenticated account back into
  /// the reviewer queue. Multipart 2xx alone is insufficient because some
  /// deployments acknowledge an upload before the profile serializer is
  /// visible to the reviewer queue.
  Future<Map<String, dynamic>> _confirmServerResubmission({
    required UserProfile profile,
    required Map<String, dynamic> uploadResponse,
  }) async {
    bool responseMatches(dynamic response) => _responseMaps(response)
        .any((record) => _recordConfirmsResubmission(record, profile: profile));

    if (responseMatches(uploadResponse)) return uploadResponse;

    // The profile write and admin review listing may be briefly eventually
    // consistent. Re-read the authenticated account before showing success.
    const retryDelays = [
      Duration.zero,
      Duration(milliseconds: 350),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1400),
      Duration(milliseconds: 2500),
    ];
    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      final delay = retryDelays[attempt];
      if (delay > Duration.zero) await Future.delayed(delay);
      try {
        final current = await _client.get('/accounts/profile/');
        if (responseMatches(current)) return current;
      } on ApiException catch (error) {
        final hasAnotherAttempt = attempt + 1 < retryDelays.length;
        if (!error.isRetryable || !hasAnotherAttempt) rethrow;
      }
    }

    throw const ApiException(
      statusCode: 409,
      message: 'The server has not confirmed the updated KYC record for review yet. Please refresh your profile before trying again.',
      errorCode: 'KYC_RESUBMISSION_NOT_CONFIRMED',
    );
  }

  Future<Map<String, dynamic>> _patchProfileResubmission({
    required UserProfile profile,
    required Map<String, String> fields,
    required List<http.MultipartFile> Function() filesBuilder,
  }) async {
    late final Map<String, dynamic> response;
    try {
      response = await _client.patchMultipart(
        '/accounts/profile/',
        fields: fields,
        filesBuilder: filesBuilder,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      response = await _client.patchMultipart(
        '/kyc/submit',
        fields: fields,
        filesBuilder: filesBuilder,
      );
    }
    return _confirmServerResubmission(
      profile: profile,
      uploadResponse: response,
    );
  }

  /// Resubmits edited profile details and replacement identity documents for review
  /// via `PATCH /accounts/profile/`.
  /// The caller updates local review state only after the server confirms `"resubmitted"`.
  Future<Map<String, dynamic>> resubmitEditedProfile({
    required UserProfile profile,
    Uint8List? selfieBytes,
    Uint8List? cnicFrontBytes,
    Uint8List? cnicBackBytes,
    String? selfieFileName,
    String? cnicFrontFileName,
    String? cnicBackFileName,
  }) async {
    final frontExtension = cnicFrontBytes != null
        ? _validateUploadImage(
            cnicFrontBytes,
            documentLabel: 'CNIC Front',
            errorCode: 'KYC_FRONT_IMAGE_INVALID',
          )
        : null;
    final backExtension = cnicBackBytes != null
        ? _validateUploadImage(
            cnicBackBytes,
            documentLabel: 'CNIC Back',
            errorCode: 'KYC_BACK_IMAGE_INVALID',
          )
        : null;
    final selfieExtension = selfieBytes != null
        ? _validateUploadImage(
            selfieBytes,
            documentLabel: 'Selfie',
            errorCode: 'KYC_SELFIE_INVALID',
          )
        : null;

    if (!AppConfig.hasCustomBackend) {
      await Future.delayed(const Duration(milliseconds: 300));
      return const {};
    }

    final fields = _buildPatchResubmissionFields(
      fullName: profile.fullName,
      countryCode: profile.countryCode,
      phoneNumber: profile.phoneNumber,
      cnicNumber: profile.cnicNumber,
      city: profile.city,
      address: profile.address,
    );

    List<http.MultipartFile> buildFiles() => [
      if (cnicFrontBytes != null)
        http.MultipartFile.fromBytes(
          'cnic_front',
          cnicFrontBytes,
          filename: cnicFrontFileName?.isNotEmpty == true
              ? cnicFrontFileName!
              : 'cnic_front.$frontExtension',
        ),
      if (cnicBackBytes != null)
        http.MultipartFile.fromBytes(
          'cnic_back',
          cnicBackBytes,
          filename: cnicBackFileName?.isNotEmpty == true
              ? cnicBackFileName!
              : 'cnic_back.$backExtension',
        ),
      if (selfieBytes != null)
        http.MultipartFile.fromBytes(
          'selfie',
          selfieBytes,
          filename: selfieFileName?.isNotEmpty == true
              ? selfieFileName!
              : 'selfie.$selfieExtension',
        ),
    ];

    return _patchProfileResubmission(
      profile: profile,
      fields: fields,
      filesBuilder: buildFiles,
    );
  }

  /// Submits regulatory KYC verification package (documents, biometric, and bank details).
  ///
  /// Reports real-time stage progress `[0.0 .. 1.0]` via optional [onProgress]
  /// callback so the submission button can render smooth live feedback.
  Future<bool> submitKyc(
    KycState state, {
    void Function(double progress, String statusLabel)? onProgress,
  }) async {
    final isResubmission =
        UserProfileRepository.instance.profile.kycStatus ==
        KycReviewStatus.rejected;
    var resubmissionMarkedLocally = false;
    onProgress?.call(0.10, 'Preparing verification package...');
    if (AppConfig.hasCustomBackend) {
      final serverPhone = _serverPhone(
        countryCode: state.personal.countryCode,
        phoneNumber: state.personal.phoneNumber,
      );
      final serverCnic = _serverCnic(state.identity.cnicNumber);
      final fields = <String, String>{
        'fullName': state.personal.fullName,
        'full_name': state.personal.fullName,
        'countryCode': state.personal.countryCode,
        'country_code': state.personal.countryCode,
        'phoneNumber': serverPhone,
        'phone': serverPhone,
        if (state.personal.city != null && state.personal.city!.isNotEmpty) ...{
          'city': state.personal.city!,
        },
        if (state.personal.address != null &&
            state.personal.address!.isNotEmpty) ...{
          'address': state.personal.address!,
        },
        'cnicNumber': serverCnic,
        'cnic_number': serverCnic,
        'bankName': state.bank.bankName,
        'bank_name': state.bank.bankName,
        'accountTitle': state.bank.beneficiaryTitle,
        'holder_name': state.bank.beneficiaryTitle,
        'bank_holder_name': state.bank.beneficiaryTitle,
        'accountNumber': state.bank.accountNumber,
        'account_number': state.bank.accountNumber,
        'bank_account_number': state.bank.accountNumber,
        'iban': state.bank.iban,
        'bank_iban': state.bank.iban,
      };

      final frontBytes =
          state.identity.enhancedFrontBytes ?? state.identity.frontBytes;
      if (frontBytes == null || frontBytes.isEmpty) {
        throw const ApiException(
          statusCode: 422,
          message: 'Select a clear CNIC front image before submitting KYC.',
          errorCode: 'KYC_FRONT_IMAGE_REQUIRED',
        );
      }
      final backBytes =
          state.identity.enhancedBackBytes ?? state.identity.backBytes;
      if (backBytes == null || backBytes.isEmpty) {
        throw const ApiException(
          statusCode: 422,
          message: 'Select a clear CNIC back image before submitting KYC.',
          errorCode: 'KYC_BACK_IMAGE_REQUIRED',
        );
      }
      final selfieBytes = state.photo.enhancedBytes ?? state.photo.bytes;
      if (selfieBytes == null || selfieBytes.isEmpty) {
        throw const ApiException(
          statusCode: 422,
          message: 'Select a selfie before submitting KYC.',
          errorCode: 'KYC_SELFIE_REQUIRED',
        );
      }
      final frontExtension = _validateUploadImage(
        frontBytes,
        documentLabel: 'CNIC Front',
        errorCode: 'KYC_FRONT_IMAGE_INVALID',
      );
      final backExtension = _validateUploadImage(
        backBytes,
        documentLabel: 'CNIC Back',
        errorCode: 'KYC_BACK_IMAGE_INVALID',
      );
      final selfieExtension = _validateUploadImage(
        selfieBytes,
        documentLabel: 'Selfie',
        errorCode: 'KYC_SELFIE_INVALID',
      );
      // Rebuild every MultipartFile for each attempt because the HTTP package
      // consumes each file stream when a request is finalized.
      List<http.MultipartFile> buildFiles() => [
        http.MultipartFile.fromBytes(
          'cnic_front',
          frontBytes,
          filename: 'cnic_front.$frontExtension',
        ),
        http.MultipartFile.fromBytes(
          'cnic_back',
          backBytes,
          filename: 'cnic_back.$backExtension',
        ),
        http.MultipartFile.fromBytes(
          'selfie',
          selfieBytes,
          filename: 'selfie.$selfieExtension',
        ),
      ];

      onProgress?.call(0.24, 'Uploading identity documents...');
      if (isResubmission) {
        final currentProfile = UserProfileRepository.instance.profile.copyWith(
          fullName: state.personal.fullName,
          phoneNumber: serverPhone,
          cnicNumber: serverCnic,
          city: state.personal.city ?? '',
          address: state.personal.address ?? '',
        );
        final patchFields = _buildPatchResubmissionFields(
          fullName: state.personal.fullName,
          countryCode: state.personal.countryCode,
          phoneNumber: state.personal.phoneNumber,
          cnicNumber: state.identity.cnicNumber,
          city: state.personal.city ?? '',
          address: state.personal.address ?? '',
        );
        final confirmedResponse = await _patchProfileResubmission(
          profile: currentProfile,
          fields: patchFields,
          filesBuilder: buildFiles,
        );

        // Update local review state only after PATCH /accounts/profile/ confirms
        // the resubmitted status on the server.
        UserProfileRepository.instance.syncFromKyc(state);
        UserProfileRepository.instance.markKycResubmitted(
          submittedAt: parseResubmittedAt(confirmedResponse),
          selfieUrl: parseDocumentUrl(confirmedResponse, const [
            'selfie_url',
            'selfieUrl',
            'selfie',
          ]),
          cnicFrontUrl: parseDocumentUrl(confirmedResponse, const [
            'cnic_front_url',
            'cnicFrontUrl',
            'cnic_front',
          ]),
          cnicBackUrl: parseDocumentUrl(confirmedResponse, const [
            'cnic_back_url',
            'cnicBackUrl',
            'cnic_back',
          ]),
        );
        resubmissionMarkedLocally = true;
      } else {
        try {
          await _client.postMultipart(
            '/accounts/profile/',
            fields: fields,
            filesBuilder: buildFiles,
          );
        } on ApiException catch (e) {
          if (e.statusCode == 404) {
            await _client.postMultipart(
              '/kyc/submit',
              fields: fields,
              filesBuilder: buildFiles,
            );
          } else {
            rethrow;
          }
        }
      }

      // Record bank account on server
      onProgress?.call(0.72, 'Linking bank account...');
      try {
        await createBankAccount(
          BankAccountItem(
            id: 'kyc_pending',
            bankName: state.bank.bankName,
            holder: state.bank.beneficiaryTitle,
            accountNumber: state.bank.accountNumber,
            iban: state.bank.iban,
            isPrimary: true,
          ),
          persistLocally: false,
        );
      } catch (_) {
        // Soft fallback if bank endpoint rejects duplicate or optional metadata
      }

      // Record onboarding progress step on server for initial submission
      onProgress?.call(0.90, 'Finalizing setup...');
      if (!isResubmission) {
        try {
          await _client.patch(
            '/auth/onboarding-step/',
            body: {'step': 4, 'is_profile_complete': true},
          );
        } catch (_) {
          // Non-blocking step update
        }
      }
    } else {
      // Local simulated processing stages
      onProgress?.call(0.35, 'Uploading identity documents...');
      await Future.delayed(const Duration(milliseconds: 140));
      onProgress?.call(0.72, 'Linking bank account...');
      await Future.delayed(const Duration(milliseconds: 140));
      onProgress?.call(0.92, 'Finalizing setup...');
      await Future.delayed(const Duration(milliseconds: 120));
    }

    // Persist initial submissions once all existing setup steps have completed.
    // Resubmissions are already saved as soon as the server accepts the KYC
    // bundle above so sidecar requests cannot delay the status transition.
    if (!resubmissionMarkedLocally) {
      UserProfileRepository.instance.syncFromKyc(state);
      if (isResubmission) {
        UserProfileRepository.instance.markKycResubmitted();
      } else {
        UserProfileRepository.instance.markKycCompleted();
      }
    }
    if (AppConfig.hasCustomBackend) {
      unawaited(
        fetchBankAccounts(email: UserProfileRepository.instance.profile.email)
            .catchError((_) => <BankAccountItem>[]),
      );
    }
    onProgress?.call(1.0, 'Verification submitted!');
    return true;
  }

  /// Retrieves the user's saved onboarding progress and draft data (GET /auth/onboarding-step/)
  Future<Map<String, dynamic>> getOnboardingProgress() async {
    if (AppConfig.hasCustomBackend) {
      try {
        return await _client.get('/auth/onboarding-step/');
      } catch (e) {
        debugPrint('[KycRepository] Fetch onboarding draft failed: $e');
      }
    }
    return {};
  }

  /// Saves step draft fields and files as user progresses through KYC (PATCH /auth/onboarding-step/)
  Future<Map<String, dynamic>> saveOnboardingStepDraft({
    required int step,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    if (AppConfig.hasCustomBackend) {
      if (files != null &&
          files.any((f) => f.length > KycImageValidation.maxFileSizeBytes)) {
        throw const ApiException(
          statusCode: 422,
          message:
              'Picture must be 5 MB or smaller. Please choose a smaller image.',
          errorCode: 'KYC_IMAGE_TOO_LARGE',
        );
      }
      try {
        if (files != null && files.isNotEmpty) {
          final allFields = <String, String>{
            'step': step.toString(),
            ...?fields,
          };
          return await _client.postMultipart(
            '/auth/onboarding-step/',
            fields: allFields,
            files: files,
          );
        } else {
          final body = <String, dynamic>{'step': step, ...?fields};
          return await _client.patch('/auth/onboarding-step/', body: body);
        }
      } catch (e) {
        debugPrint('[KycRepository] Save onboarding step $step failed: $e');
      }
    }
    return {};
  }

  /// Enhances KYC documents and selfie using backend CV pipeline (POST /accounts/process-img/)
  Future<Map<String, dynamic>> processKycImages({
    List<int>? frontBytes,
    List<int>? backBytes,
    List<int>? selfieBytes,
  }) async {
    if (AppConfig.hasCustomBackend) {
      final files = <http.MultipartFile>[];
      if (frontBytes != null) {
        final safeFront = Uint8List.fromList(frontBytes);
        KycImageValidation.validateMaxFileSize(
          safeFront,
          documentLabel: 'CNIC Front',
        );
        files.add(
          http.MultipartFile.fromBytes(
            'cnic_front',
            safeFront,
            filename: 'cnic_front.jpg',
          ),
        );
      }
      if (backBytes != null) {
        final safeBack = Uint8List.fromList(backBytes);
        KycImageValidation.validateMaxFileSize(
          safeBack,
          documentLabel: 'CNIC Back',
        );
        files.add(
          http.MultipartFile.fromBytes(
            'cnic_back',
            safeBack,
            filename: 'cnic_back.jpg',
          ),
        );
      }
      if (selfieBytes != null) {
        final safeSelfie = Uint8List.fromList(selfieBytes);
        KycImageValidation.validateMaxFileSize(
          safeSelfie,
          documentLabel: 'Selfie',
        );
        files.add(
          http.MultipartFile.fromBytes(
            'selfie',
            safeSelfie,
            filename: 'selfie.jpg',
          ),
        );
      }

      if (files.isNotEmpty) {
        try {
          return await _client.postMultipart(
            '/accounts/process-img/',
            fields: {},
            files: files,
          );
        } catch (e) {
          debugPrint('[KycRepository] Backend CV processing warning: $e');
        }
      }
    }
    return {};
  }

  /// Fetches list of active commercial Pakistani banks (GET /banking/banks/pk/)
  Future<List<Map<String, dynamic>>> getPakistaniBanks() async {
    if (AppConfig.hasCustomBackend) {
      try {
        final res = await _client.get('/banking/banks/pk/');
        return _extractMapList(res)
            .where((b) => b['is_active'] != false)
            .toList();
      } catch (e) {
        debugPrint('[KycRepository] Fetch active banks error: $e');
      }
    }
    return [];
  }

  static List<Map<String, dynamic>> _extractMapList(dynamic raw) {
    final result = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        final map = _asStringMap(item);
        if (map != null) result.add(map);
      }
      return result;
    }
    final map = _asStringMap(raw);
    if (map == null) return result;
    for (final key in const [
      'results',
      'data',
      'bank_accounts',
      'bankAccounts',
      'accounts',
      'banks',
      'items',
    ]) {
      final candidate = map[key];
      if (candidate is List || candidate is Map) {
        final nested = _extractMapList(candidate);
        if (nested.isNotEmpty) return nested;
      }
    }
    return result;
  }

  static String _normalizeBankLookup(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\)\.,\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<Map<String, dynamic>?> _resolveServerBankEntry(
    String bankNameOrCode,
  ) async {
    final catalogBank = findPakistaniBank(bankNameOrCode);
    final rule = BankAccountValidator.getRule(bankNameOrCode);
    final rawNorm = _normalizeBankLookup(bankNameOrCode);
    final catalogNameNorm = _normalizeBankLookup(catalogBank.name);
    final candidateCodes = <String>{
      catalogBank.code.toLowerCase(),
      rule.ibanBankCode.toLowerCase(),
      if (rawNorm.isNotEmpty && !rawNorm.contains(' ')) rawNorm,
    };
    final candidateAliases = <String>{
      if (rawNorm.isNotEmpty) rawNorm,
      catalogNameNorm,
      ...catalogBank.aliases.map(_normalizeBankLookup),
    };

    final banks = await getPakistaniBanks();
    for (final entry in banks) {
      final entryName = _normalizeBankLookup(
        '${entry['name'] ?? entry['short_name'] ?? ''}',
      );
      final entryCode = '${entry['code'] ?? entry['bank_code'] ?? ''}'
          .trim()
          .toLowerCase();
      if (candidateCodes.contains(entryCode) ||
          candidateAliases.contains(entryName)) {
        return entry;
      }
    }
    for (final entry in banks) {
      final entryName = _normalizeBankLookup(
        '${entry['name'] ?? entry['short_name'] ?? ''}',
      );
      if (entryName.isNotEmpty &&
          candidateAliases.any(
            (a) =>
                a.isNotEmpty &&
                (entryName.contains(a) || a.contains(entryName)),
          )) {
        return entry;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _buildBankAccountPayload(
    BankAccountItem account, {
    bool requireBankId = true,
  }) async {
    dynamic serverBankId = int.tryParse(account.bankId ?? '');
    if (serverBankId == null) {
      final matched = await _resolveServerBankEntry(account.bankName);
      final rawId = matched?['id'] ?? matched?['pk'] ?? matched?['uuid'];
      serverBankId = rawId is int
          ? rawId
          : int.tryParse('${rawId ?? ''}') ?? rawId;
    }
    if (requireBankId && serverBankId == null) {
      throw ApiException(
        statusCode: 400,
        message:
            'Could not resolve "${account.bankName}" from the active banks list.',
        errorCode: 'BANK_ID_REQUIRED',
      );
    }

    final cleanAccountNumber = account.accountNumber.replaceAll(
      RegExp(r'[\s\-]'),
      '',
    );
    final cleanIban = account.iban.trim().toUpperCase();

    return <String, dynamic>{
      'bank': ?serverBankId,
      'holder_name': account.holder.trim(),
      'account_number': cleanAccountNumber,
      if (cleanIban.isNotEmpty) 'iban': cleanIban,
      'is_primary': account.isPrimary,
    };
  }

  static List<BankAccountItem> _sortPrimaryFirst(List<BankAccountItem> items) {
    final sorted = List<BankAccountItem>.from(items);
    sorted.sort((a, b) {
      if (a.isPrimary == b.isPrimary) return 0;
      return a.isPrimary ? -1 : 1;
    });
    return sorted;
  }

  /// Fetches the authenticated user's bank accounts from `GET /banking/bank-accounts/`
  /// and synchronizes local repository cache.
  Future<List<BankAccountItem>> fetchBankAccounts({String? email}) async {
    final targetEmail = (email ?? UserProfileRepository.instance.profile.email)
        .trim();
    if (!AppConfig.hasCustomBackend) {
      if (targetEmail.isEmpty) return const <BankAccountItem>[];
      return UserProfileRepository.instance.loadBankAccounts(targetEmail);
    }

    try {
      final res = await _client.get('/banking/bank-accounts/');
      final items = _extractMapList(res);
      final parsed = _sortPrimaryFirst(
        items.map(BankAccountItem.fromJson).toList(),
      );
      if (targetEmail.isNotEmpty) {
        await UserProfileRepository.instance.saveBankAccounts(
          targetEmail,
          parsed,
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('[KycRepository] Fetch bank accounts failed: $e');
      if (targetEmail.isNotEmpty) {
        return UserProfileRepository.instance.loadBankAccounts(targetEmail);
      }
      return const [];
    }
  }

  /// Creates a linked bank account on `POST /banking/bank-accounts/` and updates local cache.
  Future<BankAccountItem> createBankAccount(
    BankAccountItem account, {
    String? email,
    bool persistLocally = true,
  }) async {
    final targetEmail = (email ?? UserProfileRepository.instance.profile.email)
        .trim();
    if (!AppConfig.hasCustomBackend) {
      if (persistLocally && targetEmail.isNotEmpty) {
        final existing = UserProfileRepository.instance.getBankAccountsSync(
          targetEmail,
        );
        final next = _sortPrimaryFirst([
          if (account.isPrimary)
            ...existing.map((a) => a.copyWith(isPrimary: false))
          else
            ...existing,
          account,
        ]);
        await UserProfileRepository.instance.saveBankAccounts(
          targetEmail,
          next,
        );
      }
      return account;
    }

    final payload = await _buildBankAccountPayload(account);
    final res = await _client.post('/banking/bank-accounts/', body: payload);

    final recordMap = _asStringMap(res['data']) ?? res;
    final created =
        recordMap.containsKey('id') ||
            recordMap.containsKey('account_number') ||
            recordMap.containsKey('holder_name')
        ? BankAccountItem.fromJson(recordMap)
        : account;

    if (persistLocally && targetEmail.isNotEmpty) {
      final refreshed = await fetchBankAccounts(email: targetEmail);
      if (refreshed.isEmpty) {
        await UserProfileRepository.instance.saveBankAccounts(targetEmail, [
          created,
        ]);
      }
    }
    return created;
  }

  static bool _isLocalOnlyId(String id) =>
      id.startsWith('bank_') || id.startsWith('kyc_');

  /// Updates an existing bank account via `PATCH /banking/bank-accounts/<id>/`.
  Future<BankAccountItem> updateBankAccount(
    BankAccountItem account, {
    String? email,
  }) async {
    final targetEmail = (email ?? UserProfileRepository.instance.profile.email)
        .trim();
    if (!AppConfig.hasCustomBackend || _isLocalOnlyId(account.id)) {
      if (AppConfig.hasCustomBackend && _isLocalOnlyId(account.id)) {
        return createBankAccount(account, email: targetEmail);
      }
      if (targetEmail.isNotEmpty) {
        final existing = List<BankAccountItem>.from(
          UserProfileRepository.instance.getBankAccountsSync(targetEmail),
        );
        final idx = existing.indexWhere((a) => a.id == account.id);
        if (idx >= 0) existing[idx] = account;
        await UserProfileRepository.instance.saveBankAccounts(
          targetEmail,
          existing,
        );
      }
      return account;
    }

    final res = await _client.patch(
      '/banking/bank-accounts/${account.id}/',
      body: await _buildBankAccountPayload(account),
    );
    final recordMap = _asStringMap(res['data']) ?? res;
    final updated =
        recordMap.containsKey('id') || recordMap.containsKey('account_number')
        ? BankAccountItem.fromJson(recordMap)
        : account;
    if (targetEmail.isNotEmpty) {
      await fetchBankAccounts(email: targetEmail);
    }
    return updated;
  }

  /// Marks an account as primary via `POST /banking/bank-accounts/{id}/make_primary/`
  /// (with `PATCH /banking/bank-accounts/{id}/` fallback).
  Future<void> setPrimaryBankAccount(
    BankAccountItem account, {
    String? email,
  }) async {
    final targetEmail = (email ?? UserProfileRepository.instance.profile.email)
        .trim();
    if (!AppConfig.hasCustomBackend || _isLocalOnlyId(account.id)) {
      if (targetEmail.isNotEmpty) {
        final existing = UserProfileRepository.instance.getBankAccountsSync(
          targetEmail,
        );
        final next = existing
            .map((a) => a.copyWith(isPrimary: a.id == account.id))
            .toList();
        await UserProfileRepository.instance.saveBankAccounts(
          targetEmail,
          next,
        );
      }
      return;
    }

    try {
      await _client.post(
        '/banking/bank-accounts/${account.id}/make_primary/',
        body: const {},
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        await _client.patch(
          '/banking/bank-accounts/${account.id}/',
          body: {'is_primary': true},
        );
      } else {
        rethrow;
      }
    }
    if (targetEmail.isNotEmpty) {
      await fetchBankAccounts(email: targetEmail);
    }
  }

  /// Deletes a non-primary bank account via `DELETE /banking/bank-accounts/<id>/`.
  Future<void> deleteBankAccount(
    BankAccountItem account, {
    String? email,
  }) async {
    if (account.isPrimary) {
      throw const ApiException(
        statusCode: 400,
        message: 'Primary bank account cannot be removed. Set another account as primary first.',
        errorCode: 'PRIMARY_ACCOUNT_PROTECTED',
      );
    }
    final targetEmail = (email ?? UserProfileRepository.instance.profile.email)
        .trim();
    if (!AppConfig.hasCustomBackend || _isLocalOnlyId(account.id)) {
      if (targetEmail.isNotEmpty) {
        final existing = List<BankAccountItem>.from(
          UserProfileRepository.instance.getBankAccountsSync(targetEmail),
        )..removeWhere((a) => a.id == account.id);
        await UserProfileRepository.instance.saveBankAccounts(
          targetEmail,
          existing,
        );
      }
      return;
    }

    await _client.delete('/banking/bank-accounts/${account.id}/');
    if (targetEmail.isNotEmpty) {
      await fetchBankAccounts(email: targetEmail);
    }
  }

  /// Inspects customer's current KYC verification status (GET /accounts/profile/)
  Future<Map<String, dynamic>> getKycProfileStatus() async {
    if (AppConfig.hasCustomBackend) {
      try {
        return await _client.get('/accounts/profile/');
      } catch (e) {
        debugPrint('[KycRepository] Fetch profile status error: $e');
      }
    }
    return {};
  }
}
