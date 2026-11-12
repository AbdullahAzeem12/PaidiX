/// Application entry point: initializes Flutter error handling and starts PaidiX.

import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';
import 'features/kyc/data/kyc_media_recovery.dart';
import 'features/profile/data/user_profile_repository.dart';

/// Configures and launches the application or test suite.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against unhandled asynchronous errors from freezing the UI
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  // Restore persisted auth session and user profile with bounded timeouts so
  // keystore or disk stalls after OS process restarts cannot freeze LaunchTheme.
  try {
    await Future.wait([
      ApiClient.instance.initSession(),
      UserProfileRepository.instance.init(),
    ]).timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('Startup session/profile restore skipped: $e');
  }

  try {
    await KycMediaRecovery.recoverAfterAndroidRestart()
        .timeout(const Duration(milliseconds: 1500));
  } catch (e) {
    debugPrint('Startup KYC media recovery skipped: $e');
  }

  runApp(const PaidiXApp());
}
