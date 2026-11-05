/// Application entry point: initializes Flutter error handling and starts PaidiX.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'app/app.dart';

/// Configures and launches the application or test suite.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against unhandled asynchronous errors from freezing the UI
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  runApp(const PaidiXApp());
}
