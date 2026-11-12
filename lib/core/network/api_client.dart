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

/// Why the client can no longer use the current authenticated session.
enum SessionInvalidationReason { refreshRejected, accountUnavailable }

/// A user-safe event for the app layer to clear local state and route to sign-in.
class SessionInvalidation {
  final SessionInvalidationReason reason;

  const SessionInvalidation(this.reason);

  String get title => reason == SessionInvalidationReason.accountUnavailable
      ? 'Account unavailable'
      : 'Session expired';

  String get message => reason == SessionInvalidationReason.accountUnavailable
      ? 'This account is no longer available. Please contact support if you believe this is an error.'
      : 'Your session expired or was revoked. Please sign in again.';
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
  Future<bool>? _refreshInFlight;
  int? _refreshFlightSessionGeneration;
  int _sessionGeneration = 0;
  bool _sessionInvalidationSignaled = false;

  /// Emits when an authenticated session is confirmed to be unusable.
  final ValueNotifier<SessionInvalidation?> sessionInvalidationNotifier =
      ValueNotifier<SessionInvalidation?>(null);

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

  /// Headers for private media owned by this API. Credentials are only sent
  /// when the media URL shares the configured API origin.
  Map<String, String> imageHeadersFor(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final apiOrigin = Uri.tryParse(AppConfig.apiBaseUrl);
    if (uri == null || apiOrigin == null || uri.origin != apiOrigin.origin) {
      return const {'Accept': 'image/*'};
    }
    return {
      'Accept': 'image/*',
      if (AppConfig.clientApiKey.isNotEmpty)
        'X-Client-Key': AppConfig.clientApiKey,
      if (_authToken != null && _authToken!.isNotEmpty)
        'Authorization': 'Bearer $_authToken',
    };
  }

  /// Resolves server media paths against the configured API base URL.
  String resolveMediaUrl(String path) => _buildUri(path).toString();

  bool get _isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Updates and persists the active JWT session tokens.
  Future<void> setAuthTokens({String? access, String? refresh}) async {
    await _persistTokens(
      access: access,
      refresh: refresh,
      startsNewSession: true,
    );
  }

  Future<void> _persistTokens({
    required String? access,
    required String? refresh,
    required bool startsNewSession,
  }) async {
    if (startsNewSession) _sessionGeneration++;
    _authToken = access;
    if (refresh != null) {
      _refreshToken = refresh;
    }
    if (startsNewSession && access != null && access.isNotEmpty) {
      _sessionInvalidationSignaled = false;
      sessionInvalidationNotifier.value = null;
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
          await _secureStorage.write(
              key: _refreshTokenStorageKey, value: refresh);
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] Secure storage write warning: $e');
    }
  }

  /// Updates and persists the active JWT session token.
  Future<void> setAuthToken(String? token) async {
    // A single-token session must not inherit a refresh token from a prior user.
    await setAuthTokens(access: token, refresh: '');
  }

  /// Initializes the token from secure storage upon application start.
  Future<void> initSession() async {
    if (_isTestEnvironment) return;
    try {
      _authToken = await _secureStorage
          .read(key: _tokenStorageKey)
          .timeout(const Duration(seconds: 2));
      _refreshToken = await _secureStorage
          .read(key: _refreshTokenStorageKey)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[ApiClient] Secure storage read warning: $e');
      final lower = e.toString().toLowerCase();
      // Corrupted KeyStore entries on vendor ROMs can throw padding/decryption
      // errors permanently unless cleared.
      if (lower.contains('badpadding') ||
          lower.contains('aeadbadtag') ||
          lower.contains('decrypt') ||
          lower.contains('keystore')) {
        try {
          await _secureStorage
              .deleteAll()
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
    }
  }

  /// Clears active session tokens (used during logout).
  Future<void> clearSession() async {
    _sessionGeneration++;
    _sessionInvalidationSignaled = false;
    sessionInvalidationNotifier.value = null;
    await _clearSessionTokens();
  }

  Future<void> _clearSessionTokens() async {
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
    final sessionGeneration = _sessionGeneration;
    final inFlight = _refreshInFlight;
    if (inFlight != null &&
        _refreshFlightSessionGeneration == sessionGeneration) {
      return inFlight;
    }
    final refresh = _refreshToken;
    final refreshFuture = _performTokenRefresh(
      refresh,
      sessionGeneration,
    );
    _refreshInFlight = refreshFuture;
    _refreshFlightSessionGeneration = sessionGeneration;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
        _refreshFlightSessionGeneration = null;
      }
    }
  }

  Future<bool> _performTokenRefresh(
    String? refresh,
    int sessionGeneration,
  ) async {
    if (refresh == null || refresh.isEmpty) {
      await _invalidateSession(
        SessionInvalidationReason.refreshRejected,
        expectedSessionGeneration: sessionGeneration,
      );
      return false;
    }

    try {
      final uri = _buildUri('/auth/refresh/');
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (AppConfig.clientApiKey.isNotEmpty)
                'X-Client-Key': AppConfig.clientApiKey,
            },
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(AppConfig.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded =
            response.body.isEmpty ? null : jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded : const {};
        final newAccess = data['access'] as String? ?? data['token'] as String?;
        if (newAccess == null || newAccess.isEmpty) return false;
        if (sessionGeneration != _sessionGeneration ||
            refresh != _refreshToken) {
          return false;
        }
        final rotatedRefresh = data['refresh'];
        await _persistTokens(
          access: newAccess,
          refresh: rotatedRefresh is String ? rotatedRefresh : null,
          startsNewSession: false,
        );
        return true;
      }

      final failure = _exceptionFromResponse(response);
      if (failure.statusCode == 401) {
        await _invalidateSession(
          _isUnavailableAccountError(failure)
              ? SessionInvalidationReason.accountUnavailable
              : SessionInvalidationReason.refreshRejected,
          expectedSessionGeneration: sessionGeneration,
        );
      } else if (_isUnavailableAccountError(failure)) {
        await _invalidateSession(
          SessionInvalidationReason.accountUnavailable,
          expectedSessionGeneration: sessionGeneration,
        );
      }
      return false;
    } on SocketException {
      // Keep the session so the user can retry after a connectivity failure.
      return false;
    } on TimeoutException {
      return false;
    } on http.ClientException catch (e) {
      debugPrint('[ApiClient] Token refresh transport failure: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ApiClient] Token refresh failed: $e');
      return false;
    }
  }

  Future<void> _invalidateSession(
    SessionInvalidationReason reason, {
    int? expectedSessionGeneration,
  }) async {
    if (expectedSessionGeneration != null &&
        expectedSessionGeneration != _sessionGeneration) {
      return;
    }
    if (_sessionInvalidationSignaled) return;
    _sessionInvalidationSignaled = true;
    _sessionGeneration++;
    await _clearSessionTokens();
    sessionInvalidationNotifier.value = SessionInvalidation(reason);
  }

  static bool _isUnavailableAccountError(ApiException error) {
    if (error.statusCode != 401 &&
        error.statusCode != 403 &&
        error.statusCode != 404) {
      return false;
    }
    final code = (error.errorCode ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return const {
      'accountnotfound',
      'usernotfound',
      'accountdeleted',
      'userdeleted',
      'accountinactive',
      'userinactive',
      'accountdisabled',
      'userdisabled',
    }.contains(code);
  }

  static bool _isInvalidAccessTokenError(ApiException error) {
    if (error.statusCode != 401) return false;
    final code = (error.errorCode ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    return code == 'token_not_valid' ||
        message.contains('token not valid') ||
        message.contains('token is invalid');
  }

  ApiException _exceptionFromResponse(http.Response response) {
    try {
      _handleResponse(response);
    } on ApiException catch (error) {
      return error;
    }
    return ApiException(
      statusCode: response.statusCode,
      message: 'The token refresh request failed.',
      errorCode: 'ERR_HTTP_${response.statusCode}',
    );
  }

  /// Assembles required headers including optional API key and Bearer auth token.
  Map<String, String> _buildHeaders({
    bool isMultipart = false,
    bool includeAuth = true,
  }) {
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AppConfig.clientApiKey.isNotEmpty)
        'X-Client-Key': AppConfig.clientApiKey,
      if (includeAuth && _authToken != null && _authToken!.isNotEmpty)
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
    Future<Map<String, dynamic>> Function() requestFn, {
    bool allowTokenRefresh = true,
  }) async {
    final requestToken = _authToken;
    final requestGeneration = _sessionGeneration;
    try {
      return await requestFn();
    } on ApiException catch (e) {
      if (!allowTokenRefresh) rethrow;
      // A response from the previous login must not operate on a newer user.
      if (requestGeneration != _sessionGeneration) rethrow;

      if (_isUnavailableAccountError(e)) {
        await _invalidateSession(
          SessionInvalidationReason.accountUnavailable,
          expectedSessionGeneration: requestGeneration,
        );
        rethrow;
      }

      if (_isInvalidAccessTokenError(e)) {
        // Reuse a newer access token if another request already refreshed ours.
        if (requestToken != null && requestToken != _authToken) {
          return _replayAuthenticatedRequest(requestFn, requestGeneration);
        }
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          if (requestGeneration != _sessionGeneration) rethrow;
          return _replayAuthenticatedRequest(requestFn, requestGeneration);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _replayAuthenticatedRequest(
    Future<Map<String, dynamic>> Function() requestFn,
    int requestGeneration,
  ) async {
    try {
      return await requestFn();
    } on ApiException catch (error) {
      if (requestGeneration != _sessionGeneration) rethrow;
      if (_isUnavailableAccountError(error)) {
        await _invalidateSession(
          SessionInvalidationReason.accountUnavailable,
          expectedSessionGeneration: requestGeneration,
        );
      } else if (_isInvalidAccessTokenError(error)) {
        await _invalidateSession(
          SessionInvalidationReason.refreshRejected,
          expectedSessionGeneration: requestGeneration,
        );
      }
      rethrow;
    }
  }

  /// Executes an HTTP POST request with JSON payload.
  ///
  /// Set [includeAuth] to `false` for public unauthenticated endpoints (login,
  /// signup, OTP verify/resend, password reset) so stale/cross-user tokens in
  /// secure storage are never sent in `Authorization` headers.
  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    Duration? timeout,
    bool includeAuth = true,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      try {
        final response = await _httpClient
            .post(
              uri,
              headers: _buildHeaders(includeAuth: includeAuth),
              body: jsonEncode(body),
            )
            .timeout(timeout ?? AppConfig.timeoutDuration);

        return _handleResponse(response);
      } on SocketException {
        throw const ApiException(
          statusCode: 503,
          message:
              'Unable to reach the PaidiX server. Please verify your connection.',
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
    }, allowTokenRefresh: includeAuth);
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
          message:
              'Unable to reach the PaidiX server. Please verify your connection.',
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
          message:
              'Unable to reach the PaidiX server. Please verify your connection.',
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
          message:
              'Unable to reach the PaidiX server. Please verify your connection.',
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

  /// Executes a Multipart Form-Data request (POST or PATCH) for documents and images.
  Future<Map<String, dynamic>> _sendMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    List<http.MultipartFile> Function()? filesBuilder,
    Duration? timeout,
  }) async {
    return _executeWithTokenRefresh(() async {
      final uri = _buildUri(path);
      final client = _customHttpClient ?? http.Client();
      final ownsClient = _customHttpClient == null;
      try {
        final request = http.MultipartRequest(method, uri);
        request.headers.addAll(_buildHeaders(isMultipart: true));
        request.fields.addAll(fields);
        request.files.addAll(filesBuilder != null ? filesBuilder() : files);

        final streamedResponse = await client.send(request).timeout(
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
          message:
              'Document upload timed out. Please ensure images are well-lit and try again.',
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
      } finally {
        if (ownsClient) {
          client.close();
        }
      }
    });
  }

  /// Executes a Multipart Form-Data POST request (for KYC documents and selfies).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    List<http.MultipartFile> Function()? filesBuilder,
    Duration? timeout,
  }) =>
      _sendMultipart(
        'POST',
        path,
        fields: fields,
        files: files,
        filesBuilder: filesBuilder,
        timeout: timeout,
      );

  /// Executes a Multipart Form-Data PATCH request (for KYC profile resubmission).
  Future<Map<String, dynamic>> patchMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    List<http.MultipartFile> Function()? filesBuilder,
    Duration? timeout,
  }) =>
      _sendMultipart(
        'PATCH',
        path,
        fields: fields,
        files: files,
        filesBuilder: filesBuilder,
        timeout: timeout,
      );

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
    // Supports Django REST Framework shapes: { detail, code }, { error, message },
    // and field dicts.
    final rawDetail = parsedBody['detail'];
    final rawMessage = parsedBody['message'];
    final rawError = parsedBody['error'];
    final nestedError = rawError is Map
        ? rawError.map((key, value) => MapEntry('$key', value))
        : const <String, dynamic>{};

    String serverDetail = (rawDetail is String ? rawDetail : null) ??
        (rawMessage is String ? rawMessage : null) ??
        (nestedError['detail'] is String
            ? nestedError['detail'] as String
            : null) ??
        (nestedError['message'] is String
            ? nestedError['message'] as String
            : null) ??
        (rawError is String ? rawError : null) ??
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

    final rawCode = parsedBody['code'] ?? nestedError['code'];
    final rawErrorCode = parsedBody['errorCode'] ??
        parsedBody['error_code'] ??
        nestedError['errorCode'] ??
        nestedError['error_code'];
    final errorLooksLikeCode = rawError is String &&
        rawError.isNotEmpty &&
        ((rawDetail is String && rawDetail.isNotEmpty) ||
            (rawMessage is String && rawMessage.isNotEmpty) ||
            RegExp(r'^[A-Z0-9_]+$').hasMatch(rawError));

    final serverCode = (rawCode is String ? rawCode : null) ??
        (rawErrorCode is String ? rawErrorCode : null) ??
        (errorLooksLikeCode ? rawError : null) ??
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
        final retryAfterSeconds =
            retryAfterHeader != null ? int.tryParse(retryAfterHeader) : null;
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
