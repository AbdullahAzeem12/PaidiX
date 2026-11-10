/// Repository managing KYC document and identity submission to the backend.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/kyc_models.dart';
import 'kyc_image_validation.dart';

class KycRepository {
  KycRepository._();
  static final KycRepository instance = KycRepository._();

  final ApiClient _client = ApiClient.instance;

  /// Submits regulatory KYC verification package (documents, biometric, and bank details).
  ///
  /// Reports real-time stage progress `[0.0 .. 1.0]` via optional [onProgress]
  /// callback so the submission button can render smooth live feedback.
  Future<bool> submitKyc(
    KycState state, {
    void Function(double progress, String statusLabel)? onProgress,
  }) async {
    final isResubmission = UserProfileRepository.instance.profile.kycStatus ==
        KycReviewStatus.rejected;
    onProgress?.call(0.10, 'Preparing verification package...');
    if (AppConfig.hasCustomBackend) {
      final fields = <String, String>{
        'fullName': state.personal.fullName,
        'full_name': state.personal.fullName,
        'countryCode': state.personal.countryCode,
        'phoneNumber': state.personal.phoneNumber,
        'phone': state.personal.phoneNumber,
        if (state.personal.city != null && state.personal.city!.isNotEmpty) ...{
          'city': state.personal.city!,
        },
        if (state.personal.address != null &&
            state.personal.address!.isNotEmpty) ...{
          'address': state.personal.address!,
        },
        'cnicNumber': state.identity.cnicNumber,
        'cnic_number': state.identity.cnicNumber,
        'bankName': state.bank.bankName,
        'bank_name': state.bank.bankName,
        'accountTitle': state.bank.beneficiaryTitle,
        'holder_name': state.bank.beneficiaryTitle,
        'accountNumber': state.bank.accountNumber,
        'account_number': state.bank.accountNumber,
        'iban': state.bank.iban,
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
      final frontExtension = KycImageValidation.extensionFor(frontBytes);
      final backExtension = KycImageValidation.extensionFor(backBytes);
      final selfieExtension = KycImageValidation.extensionFor(selfieBytes);
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
      try {
        await _client.postMultipart(
          '/accounts/profile/',
          fields: fields,
          files: buildFiles(),
        );
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          await _client.postMultipart(
            '/kyc/submit',
            fields: fields,
            files: buildFiles(),
          );
        } else {
          rethrow;
        }
      }

      // Record bank account on server
      onProgress?.call(0.72, 'Linking bank account...');
      try {
        await _client.post(
          '/banking/bank-accounts/',
          body: {
            'holder_name': state.bank.beneficiaryTitle,
            'account_number': state.bank.accountNumber,
            if (state.bank.iban.isNotEmpty) 'iban': state.bank.iban,
            'is_primary': true,
          },
        );
      } catch (_) {
        // Soft fallback if bank master ID is required
      }

      // Record onboarding progress step on server
      onProgress?.call(0.90, 'Finalizing setup...');
      try {
        await _client.patch(
          '/auth/onboarding-step/',
          body: {
            'step': 4,
            'is_profile_complete': true,
          },
        );
      } catch (_) {
        // Non-blocking step update
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

    // Persist uploaded changes and optimistically return the review state to pending.
    UserProfileRepository.instance.syncFromKyc(state);
    if (isResubmission) {
      UserProfileRepository.instance.markKycResubmitted();
    } else {
      UserProfileRepository.instance.markKycCompleted();
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
          final body = <String, dynamic>{
            'step': step,
            ...?fields,
          };
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
        files.add(http.MultipartFile.fromBytes(
          'cnic_front',
          frontBytes,
          filename: 'cnic_front.jpg',
        ));
      }
      if (backBytes != null) {
        files.add(http.MultipartFile.fromBytes(
          'cnic_back',
          backBytes,
          filename: 'cnic_back.jpg',
        ));
      }
      if (selfieBytes != null) {
        files.add(http.MultipartFile.fromBytes(
          'selfie',
          selfieBytes,
          filename: 'selfie.jpg',
        ));
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
        if (res['data'] is List) {
          return (res['data'] as List).cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('[KycRepository] Fetch active banks error: $e');
      }
    }
    return [];
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
