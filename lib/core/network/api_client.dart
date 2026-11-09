/// Centralized resilient network client for PaidiX API requests.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Structured API exception containing HTTP status, message, error code,
/// and optional retry metadata.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;

  /// For 429 Too Many Requests: seconds the client should wait before retrying.
  final int? retryAfterSeconds;

  /// True for 429, 500, 502, 503, 504 — transient errors worth retrying.
  final bool isRetryable;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.retryAfterSeconds,
    this.isRetryable = false,
  });

  @override
  String toString() => 'ApiException($statusCode): $message (code: $errorCode)';
}

/// Core API client managing session tokens, request headers, timeouts, and responses.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _tokenStorageKey = 'paidix_auth_jwt_token';
  static const String _refreshTokenStorageKey = 'paidix_auth_refresh_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  http.Client? _customHttpClient;

  String? _authToken;
  String? _refreshToken;
  bool _isRefreshing = false;

  /// Sets a custom HTTP client (useful for unit and widget testing).
  @visibleForTesting
  set customHttpClient(http.Client? client) {
    _customHttpClient = client;
  }

  http.Client get _httpClient => _customHttpClient ?? http.Client();

  /// Gets the currently active authentication JWT access token.
  String? get authToken => _authToken;

  /// Gets the currently active JWT refresh token.
  String? get refreshToken => _refreshToken;

  bool get _isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Updates and persists the active JWT session tokens.
  Future<void> setAuthTokens({String? access, String? refresh}) async {
    _authToken = access;
    if (refresh != null) {
      _refreshToken = refresh;
    }
    if (_isTestEnvironment) return;
    try {
      if (access == null) {
        await _secureStorage.delete(key: _tokenStorageKey);
      } else {
        await _secureStorage.write(key: _tokenStorageKey, value: access);
      }
      if (refresh != null) {
        if (refresh.isEmpty) {
          await _secureStorage.delete(key: _refreshTokenStorageKey);
        } else {
          await _secureStorage.write(key: _refreshTokenStorageKey, value: refresh);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] Secure storage write warning: $e');
    }
  }

  /// Updates and persists the active JWT session token.
  Future<void> setAuthToken(String? token) async {
    await setAuthTokens(access: token);
  }

  /// Initializes the token from secure storage upon application start.
  Future<void> initSession() async {
    if (_isTestEnvironment) return;
    try {
      _authToken = await _secureStorage.read(key: _tokenStorageKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenStorageKey);
    } catch (e) {
      debugPrint('[ApiClient] Secure storage read warning: $e');
    }
  }

  /// Clears active session tokens (used during logout).
  Future<void> clearSession() async {
    _authToken = null;
    _refreshToken = null;
    if (_isTestEnvironment) return;
    try {
      await _secureStorage.delete(key: _tokenStorageKey);
      await _secureStorage.delete(key: _refreshTokenStorageKey);
    } catch (e) {
      debugPrint('[ApiClient] Secure storage clear warning: $e');
    }
  }

  /// Exchanges the refresh token for a new access token (POST /auth/refresh/).
  Future<bool> refreshAccessToken() async {
    if (_isRefreshing) return false;
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    _isRefreshing = true;
    try {
      final uri = _buildUri('/auth/refresh/');
      final response = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh': _refreshToken}),
      ).timeout(AppConfig.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['access'] as String? ?? data['token'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          await setAuthTokens(access: newAccess);
          return true;
        }
      } else if (response.statusCode == 401) {
        await clearSession();
      }
      return false;
    } catch (e) {
      debugPrint('[ApiClient] Token refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Assembles required headers including optional API key and Bearer auth token.
  Map<String, String> _buildHeaders({bool isMultipart = false}) {
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AppConfig.clientApiKey.isNotEmpty)
        'X-Client-Key': AppConfig.clientApiKey,
      if (_authToken != null && _authToken!.isNotEmpty)
        'Authorization': 'Bearer $_authToken',
    };
  }

  /// Builds a sanitized Uri avoiding double-slash, duplicate schemes, or missing slash issues.
  Uri _buildUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = AppConfig.apiBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath');
  }

  /// Wraps an HTTP request with automatic token refresh on 401 token_not_valid errors.
  Future<Map<String, dynamic>> _executeWithTokenRefresh(
    Future<Map<String, dynamic>> Function() requestFn,
  ) async {
    try {
      return await requestFn();
    } on ApiException catch (e) {
      // 401 token_not_valid → silently refresh and replay once
      if (e.statusCode == 401 &&
          (e.errorCode == 'token_not_valid' ||
              e.message.toLowerCase().contains('token not valid') ||
              e.message.toLowerCase().contains('token is invalid'))) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          return await requestFn();
        }
      }
      rethrow;
    }
  }

  /// Executes an HTTP POST request with JSON payload.
  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    Duration? timeout,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      try {
        final response = await _httpClient
            .post(
              uri,
              headers: _buildHeaders(),
              body: jsonEncode(body),
            )
            .timeout(timeout ?? AppConfig.timeoutDuration);

        return _handleResponse(response);
      } on SocketException {
        throw const ApiException(
          statusCode: 503,
          message: 'Unable to reach the PaidiX server. Please verify your connection.',
          errorCode: 'ERR_NETWORK_DISCONNECTED',
          isRetryable: true,
        );
      } on TimeoutException {
        throw const ApiException(
          statusCode: 504,
          message: 'The server request timed out. Please retry in a moment.',
          errorCode: 'ERR_GATEWAY_TIMEOUT',
          isRetryable: true,
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          statusCode: 502,
          message: 'A network communication error occurred: ${e.message}',
          errorCode: 'ERR_BAD_GATEWAY',
          isRetryable: true,
        );
      }
    });
  }

  /// Executes an HTTP PATCH request with JSON payload.
  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
    Duration? timeout,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      try {
        final response = await _httpClient
            .patch(
              uri,
              headers: _buildHeaders(),
              body: jsonEncode(body),
            )
            .timeout(timeout ?? AppConfig.timeoutDuration);

        return _handleResponse(response);
      } on SocketException {
        throw const ApiException(
          statusCode: 503,
          message: 'Unable to reach the PaidiX server. Please verify your connection.',
          errorCode: 'ERR_NETWORK_DISCONNECTED',
          isRetryable: true,
        );
      } on TimeoutException {
        throw const ApiException(
          statusCode: 504,
          message: 'The server request timed out. Please retry in a moment.',
          errorCode: 'ERR_GATEWAY_TIMEOUT',
          isRetryable: true,
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          statusCode: 502,
          message: 'A network communication error occurred: ${e.message}',
          errorCode: 'ERR_BAD_GATEWAY',
          isRetryable: true,
        );
      }
    });
  }

  /// Executes an HTTP GET request.
  Future<Map<String, dynamic>> get(
    String path, {
    Duration? timeout,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      try {
        final response = await _httpClient
            .get(
              uri,
              headers: _buildHeaders(),
            )
            .timeout(timeout ?? AppConfig.timeoutDuration);

        return _handleResponse(response);
      } on SocketException {
        throw const ApiException(
          statusCode: 503,
          message: 'Unable to reach the PaidiX server. Please verify your connection.',
          errorCode: 'ERR_NETWORK_DISCONNECTED',
          isRetryable: true,
        );
      } on TimeoutException {
        throw const ApiException(
          statusCode: 504,
          message: 'The server request timed out. Please retry in a moment.',
          errorCode: 'ERR_GATEWAY_TIMEOUT',
          isRetryable: true,
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          statusCode: 502,
          message: 'A network communication error occurred: ${e.message}',
          errorCode: 'ERR_BAD_GATEWAY',
          isRetryable: true,
        );
      }
    });
  }

  /// Executes an HTTP DELETE request (e.g. for removing Payments PIN).
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      try {
        final request = http.Request('DELETE', uri);
        request.headers.addAll(_buildHeaders());
        if (body != null) {
          request.body = jsonEncode(body);
        }

        final streamedResponse = await _httpClient
            .send(request)
            .timeout(timeout ?? AppConfig.timeoutDuration);
        final response = await http.Response.fromStream(streamedResponse);

        return _handleResponse(response);
      } on SocketException {
        throw const ApiException(
          statusCode: 503,
          message: 'Unable to reach the PaidiX server. Please verify your connection.',
          errorCode: 'ERR_NETWORK_DISCONNECTED',
          isRetryable: true,
        );
      } on TimeoutException {
        throw const ApiException(
          statusCode: 504,
          message: 'The server request timed out. Please retry in a moment.',
          errorCode: 'ERR_GATEWAY_TIMEOUT',
          isRetryable: true,
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          statusCode: 502,
          message: 'A network communication error occurred: ${e.message}',
          errorCode: 'ERR_BAD_GATEWAY',
          isRetryable: true,
        );
      }
    });
  }

  /// Executes a Multipart Form-Data POST request (for KYC documents and selfies).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    Duration? timeout,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      try {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_buildHeaders(isMultipart: true));
        request.fields.addAll(fields);
        request.files.addAll(files);

        final streamedResponse = await request.send().timeout(
              timeout ?? AppConfig.uploadTimeoutDuration,
            );
        final response = await http.Response.fromStream(streamedResponse);

        return _handleResponse(response);
      } on SocketException {
        throw const ApiException(
          statusCode: 503,
          message: 'Unable to stream documents. Please verify your connection.',
          errorCode: 'ERR_NETWORK_DISCONNECTED',
          isRetryable: true,
        );
      } on TimeoutException {
        throw const ApiException(
          statusCode: 504,
          message: 'Document upload timed out. Please ensure images are well-lit and try again.',
          errorCode: 'ERR_UPLOAD_TIMEOUT',
          isRetryable: true,
        );
      } on http.ClientException catch (e) {
        throw ApiException(
          statusCode: 502,
          message: 'Upload stream error: ${e.message}',
          errorCode: 'ERR_BAD_GATEWAY',
          isRetryable: true,
        );
      }
    });
  }

  /// Validates and parses the HTTP response, throwing a structured [ApiException]
  /// for every error status code with precise, user-facing messaging.
  ///
  /// Status code handling:
  ///  2xx → return parsed body
  ///  304 → return empty map (not modified / cache valid)
  ///  400 → Bad Request: missing fields / invalid format
  ///  401 → Unauthorized: missing or invalid credentials / expired token
  ///  403 → Forbidden: authenticated but access denied for this resource
  ///  404 → Not Found: endpoint or resource does not exist
  ///  405 → Method Not Allowed: wrong HTTP verb for this endpoint
  ///  409 → Conflict: resource already exists (duplicate account, CNIC, etc.)
  ///  429 → Too Many Requests: rate-limited; parse Retry-After header
  ///  500 → Internal Server Error: unhandled server crash
  ///  502 → Bad Gateway: upstream server returned invalid response
  ///  503 → Service Unavailable: server overloaded or under maintenance
  ///  504 → Gateway Timeout: upstream server took too long to respond
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Parse response body regardless of status so error details are available.
    Map<String, dynamic> parsedBody = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          parsedBody = decoded;
        } else {
          parsedBody = {'data': decoded};
        }
      } catch (_) {
        parsedBody = {'rawResponse': response.body};
      }
    }

    final status = response.statusCode;

    // ── 2xx Success ─────────────────────────────────────────────────────────
    if (status >= 200 && status < 300) {
      return parsedBody;
    }

    // ── 304 Not Modified ────────────────────────────────────────────────────
    // Cached version is still valid; return empty map (no body to process).
    if (status == 304) {
      return {};
    }

    // ── Extract server-provided error details ────────────────────────────────
    // Supports Django REST Framework shapes: { detail, code } and field dicts.
    String serverDetail = parsedBody['detail'] as String? ??
        parsedBody['message'] as String? ??
        parsedBody['error'] as String? ??
        '';

    if (serverDetail.isEmpty) {
      final fieldErrors = <String>[];
      parsedBody.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          fieldErrors.add('$key: ${value.first}');
        } else if (value is String && key != 'rawResponse' && key != 'code') {
          fieldErrors.add('$key: $value');
        }
      });
      serverDetail = fieldErrors.join(' ');
    }

    final serverCode = parsedBody['code'] as String? ??
        parsedBody['errorCode'] as String? ??
        'ERR_HTTP_$status';

    // ── Per-status-code precise messaging ────────────────────────────────────
    switch (status) {

      // 400 Bad Request — malformed syntax, missing required data, invalid fields
      case 400:
        throw ApiException(
          statusCode: 400,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'The request was malformed or contained invalid data. '
                  'Please check your input and try again.',
          errorCode: serverCode,
        );

      // 401 Unauthorized — credentials missing, invalid, or token expired
      case 401:
        throw ApiException(
          statusCode: 401,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'Authentication required. Your session may have expired. '
                  'Please sign in again.',
          errorCode: serverCode,
        );

      // 403 Forbidden — authenticated but not permitted to access this resource
      case 403:
        throw ApiException(
          statusCode: 403,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'You do not have permission to perform this action. '
                  'Contact support if you believe this is an error.',
          errorCode: serverCode,
        );

      // 404 Not Found — endpoint or resource does not exist on the server
      case 404:
        throw ApiException(
          statusCode: 404,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'The requested resource could not be found. '
                  'It may have been removed or the URL may be incorrect.',
          errorCode: serverCode,
        );

      // 405 Method Not Allowed — wrong HTTP verb for this endpoint
      case 405:
        throw ApiException(
          statusCode: 405,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'This action is not supported for the requested resource. '
                  'Please contact support.',
          errorCode: serverCode,
        );

      // 409 Conflict — resource already exists (e.g. duplicate email or CNIC)
      case 409:
        throw ApiException(
          statusCode: 409,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'A conflict occurred. This record may already exist.',
          errorCode: serverCode,
        );

      // 429 Too Many Requests — rate limited; include retry-after if available
      case 429:
        // Parse Retry-After header (seconds) if the server provides it
        final retryAfterHeader = response.headers['retry-after'];
        final retryAfterSeconds = retryAfterHeader != null
            ? int.tryParse(retryAfterHeader)
            : null;
        final waitHint = retryAfterSeconds != null
            ? ' Please wait $retryAfterSeconds second${retryAfterSeconds == 1 ? '' : 's'} before trying again.'
            : ' Please wait a moment before trying again.';
        throw ApiException(
          statusCode: 429,
          message: serverDetail.isNotEmpty
              ? '$serverDetail$waitHint'
              : 'Too many requests sent in a short period.$waitHint',
          errorCode: serverCode,
          retryAfterSeconds: retryAfterSeconds,
          isRetryable: true,
        );

      // 500 Internal Server Error — unhandled crash in the server backend
      case 500:
        throw ApiException(
          statusCode: 500,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'An unexpected error occurred on our servers. '
                  'Our team has been notified. Please try again shortly.',
          errorCode: serverCode,
          isRetryable: true,
        );

      // 502 Bad Gateway — upstream server returned an invalid response
      case 502:
        throw ApiException(
          statusCode: 502,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'The PaidiX gateway received an invalid response from an upstream '
                  'service. Please try again in a moment.',
          errorCode: serverCode,
          isRetryable: true,
        );

      // 503 Service Unavailable — server overloaded or under maintenance
      case 503:
        throw ApiException(
          statusCode: 503,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'The PaidiX service is temporarily unavailable. '
                  'This may be due to maintenance or high demand. Please retry shortly.',
          errorCode: serverCode,
          isRetryable: true,
        );

      // 504 Gateway Timeout — backend server took too long to respond
      case 504:
        throw ApiException(
          statusCode: 504,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'The server did not respond in time. '
                  'Please check your connection and retry.',
          errorCode: serverCode,
          isRetryable: true,
        );

      // All other status codes
      default:
        throw ApiException(
          statusCode: status,
          message: serverDetail.isNotEmpty
              ? serverDetail
              : 'Request failed with status $status.',
          errorCode: serverCode,
          isRetryable: status >= 500,
        );
    }
  }
}

