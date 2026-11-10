/// Application entry point: initializes Flutter error handling and starts PaidiX.

import 'dart:ui';
import 'package:flutter/material.dart';
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

  // Restore persisted auth session and user profile
  await ApiClient.instance.initSession();
  await UserProfileRepository.instance.init();
  await KycMediaRecovery.recoverAfterAndroidRestart();

  runApp(const PaidiXApp());
}
