import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized environment and API configuration for PaidiX.
///
/// Values can be supplied at compile-time using `--dart-define`:
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.paidix.com/v1 --dart-define=CLIENT_API_KEY=pk_live_your_key
/// ```

class AppConfig {
  AppConfig._();

  /// Default backend endpoint.
  /// Replace this with your actual backend URL (e.g., 'https://api.yourdomain.com' or 'http://10.0.2.2:8000')
  /// or pass it at runtime via `--dart-define=API_BASE_URL=...`.
  static const String defaultBaseUrl = 'https://201.79.42.93.nip.io/api/v1';

  /// Base URL for backend API requests.
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  /// Sanitized Base URL for backend API requests.
  static String get apiBaseUrl => sanitizeUrl(_rawApiBaseUrl);

  /// Cleans and sanitizes any malformed, duplicated, or quoted backend URL.
  static String sanitizeUrl(String raw) {
    var url = raw.trim();
    // Strip surrounding quotes if passed via shell
    if ((url.startsWith('"') && url.endsWith('"')) ||
        (url.startsWith("'") && url.endsWith("'"))) {
      url = url.substring(1, url.length - 1).trim();
    }
    final isExplicitHttp = url.startsWith('http://');
    // Strip any repeated or malformed protocol prefixes (e.g., https:https://, https://https://, etc.)
    url = url.replaceAll(RegExp(r'^(https?:/?/?)+', caseSensitive: false), '');
    final scheme = isExplicitHttp ? 'http://' : 'https://';
    return '$scheme$url'.replaceAll(RegExp(r'/+$'), '');
  }

  /// Client API key sent in `X-Client-Key` header (optional).
  static const String _rawClientApiKey = String.fromEnvironment(
    'CLIENT_API_KEY',
    defaultValue: '',
  );

  /// If your server does not require an API key or placeholder is passed, returns empty.
  static String get clientApiKey {
    final key = _rawClientApiKey.trim();
    if (key == 'your_key_here' || key == 'YOUR_KEY_HERE') return '';
    return key;
  }

  /// Whether code is currently executing inside Flutter's test runner.
  static bool get isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Optional override allowing tests to exercise live HTTP code paths
  /// with a mock [http.Client]. Leave `null` in production.
  @visibleForTesting
  static bool? debugOverrideCustomBackend;

  /// Whether a live backend URL has been configured (either in code or via `--dart-define`).
  static bool get hasCustomBackend =>
      debugOverrideCustomBackend ??
      (!isTestEnvironment &&
          apiBaseUrl.isNotEmpty &&
          apiBaseUrl != 'https://api-staging.paidix.com/v1');

  /// Default timeout duration for standard JSON REST requests.
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Extended timeout duration for multipart KYC document and image uploads.
  static const Duration uploadTimeoutDuration = Duration(seconds: 45);
}
