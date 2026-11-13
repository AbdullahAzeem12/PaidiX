import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/kyc_models.dart';
import '../../profile/data/user_profile_repository.dart';
import 'kyc_image_validation.dart';

/// Recovers a gallery result if Android reclaimed MainActivity while the
/// external picker was open. Must run before the initial route is displayed.
class KycMediaRecovery {
  const KycMediaRecovery._();

  static bool _retrievalInFlight = false;

  /// Retrieves Android's lost picker result once, for the persisted target.
  /// Competing screens cannot consume or misroute the same result.
  static Future<XFile?> retrieveLostFileFor(String expectedSide) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final repository = UserProfileRepository.instance;
    if (repository.pendingPickSide != expectedSide || _retrievalInFlight) {
      return null;
    }

    _retrievalInFlight = true;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.exception != null) throw response.exception!;
      return response.file;
    } finally {
      _retrievalInFlight = false;
    }
  }

  static Future<void> recoverAfterAndroidRestart() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_retrievalInFlight) return;

    final repository = UserProfileRepository.instance;
    // Do not consume Android's single lost-result slot unless the app recorded
    // an interrupted KYC/profile picker. Other features (such as payment proof
    // upload) use the same platform slot and recover their own results.
    if (!const {
      'avatar',
      'cnic_front',
      'cnic_back',
      'selfie',
    }.contains(repository.pendingPickSide)) {
      return;
    }

    final picker = ImagePicker();
    _retrievalInFlight = true;
    try {
      final response = await picker.retrieveLostData();
      if (response.exception != null) {
        throw response.exception!;
      }
      final file = response.file;
      if (response.isEmpty || file == null) {
        await repository.setPendingPickSide(null);
        return;
      }

      final bytes = await file.readAsBytes();
      final validated = await KycImageValidation.validate(bytes);
      final side = _resolveTarget(repository);
      if (side == null) {
        debugPrint(
          '[KycMediaRecovery] Picked image recovered, but no KYC target was recorded.',
        );
        await repository.setPendingPickSide(null);
        return;
      }

      await repository.restoreKycPickerResult(
        side: side,
        bytes: validated,
        sourcePath: file.path,
      );
      await repository.setPendingPickSide(null);
      debugPrint('[KycMediaRecovery] Restored selected image for $side.');
    } catch (e, stackTrace) {
      debugPrint('[KycMediaRecovery] Could not restore picked image: $e');
      debugPrintStack(stackTrace: stackTrace);
      await repository.setPendingPickSide(null);
    } finally {
      _retrievalInFlight = false;
    }
  }

  static String? _resolveTarget(UserProfileRepository repository) {
    switch (repository.pendingPickSide) {
      case 'cnic_front':
      case 'cnic_back':
      case 'selfie':
      case 'avatar':
        return repository.pendingPickSide;
    }

    final profile = repository.profile;
    if (repository.activeKycStep == KycStep.photo) return 'selfie';
    if (repository.activeKycStep == KycStep.identity) {
      if (profile.cnicFrontBytes == null) return 'cnic_front';
      if (profile.cnicBackBytes == null) return 'cnic_back';
      return 'cnic_front';
    }
    return null;
  }
}
