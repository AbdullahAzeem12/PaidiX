import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/kyc_models.dart';
import '../../profile/data/user_profile_repository.dart';
import 'kyc_image_validation.dart';

/// Recovers a gallery result if Android reclaimed MainActivity while the
/// external picker was open. Must run before the initial route is displayed.
class KycMediaRecovery {
  const KycMediaRecovery._();

  static Future<void> recoverAfterAndroidRestart() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final repository = UserProfileRepository.instance;
    final picker = ImagePicker();
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
    }
  }

  static String? _resolveTarget(UserProfileRepository repository) {
    switch (repository.pendingPickSide) {
      case 'cnic_front':
      case 'cnic_back':
      case 'selfie':
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
