import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiry;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiry,
  });

  bool get isExpired =>
      DateTime.now().isAfter(expiry.subtract(AppConstants.tokenRefreshBuffer));
}

class AuthService {
  final FlutterSecureStorage _storage;
  final Dio _plainDio;

  AuthTokens? _tokens;
  String? _serverUrl;
  String _oauthClientId = AppConstants.oauthClientId;

  AuthService({
    FlutterSecureStorage? storage,
    Dio? dio,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _plainDio = dio ?? Dio();

  String? get serverUrl => _serverUrl;
  String get oauthClientId => _oauthClientId;
  AuthTokens? get tokens => _tokens;
  bool get isAuthenticated => _tokens != null && _serverUrl != null;

  /// Try to restore a previous session from secure storage.
  Future<bool> tryRestoreSession() async {
    final url = await _storage.read(key: AppConstants.keyServerUrl);
    final access = await _storage.read(key: AppConstants.keyAccessToken);
    final refresh = await _storage.read(key: AppConstants.keyRefreshToken);
    final expiryStr = await _storage.read(key: AppConstants.keyTokenExpiry);
    final clientId = await _storage.read(key: AppConstants.keyOauthClientId);

    if (url == null || access == null || refresh == null || expiryStr == null) {
      return false;
    }

    _serverUrl = url;
    _oauthClientId = (clientId == null || clientId.trim().isEmpty)
        ? AppConstants.oauthClientId
        : clientId;
    _tokens = AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiry: DateTime.parse(expiryStr),
    );

    if (_tokens!.isExpired) {
      try {
        await refreshAccessToken();
      } catch (_) {
        await logout();
        return false;
      }
    }

    return true;
  }

  /// Authenticate with password grant.
  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
    String? oauthClientId,
  }) async {
    final normalizedUrl = _normalizeServerUrl(serverUrl);
    final normalizedClientId =
        (oauthClientId == null || oauthClientId.trim().isEmpty)
            ? AppConstants.oauthClientId
            : oauthClientId.trim();

    final response = await _plainDio.post(
      '$normalizedUrl/oauth/token',
      data: {
        'grant_type': 'password',
        'client_id': normalizedClientId,
        'username': username,
        'password': password,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    _serverUrl = normalizedUrl;
    _oauthClientId = normalizedClientId;
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  String _normalizeServerUrl(String rawUrl) {
    var value = rawUrl.trim();
    if (value.isEmpty) return value;

    // Accept "farm.example.com" and default to HTTPS.
    if (!value.contains('://')) {
      value = 'https://$value';
    }

    // Keep only origin if user pastes a full page URL
    // (e.g. https://host/dashboard?... -> https://host).
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      final port = parsed.hasPort ? ':${parsed.port}' : '';
      value = '${parsed.scheme}://${parsed.host}$port';
    }

    // Remove trailing slash and accidental "/api" suffix for base URL.
    value = value.replaceAll(RegExp(r'/+$'), '');
    value = value.replaceAll(RegExp(r'/api$', caseSensitive: false), '');
    return value;
  }

  /// Refresh the access token using the refresh token.
  Future<void> refreshAccessToken() async {
    if (_tokens == null || _serverUrl == null) {
      throw StateError('No active session to refresh');
    }

    final response = await _plainDio.post(
      '$_serverUrl/oauth/token',
      data: {
        'grant_type': 'refresh_token',
        'client_id': _oauthClientId,
        'refresh_token': _tokens!.refreshToken,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    _tokens = null;
    _serverUrl = null;
    await _storage.deleteAll();
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final expiresIn = data['expires_in'] as int? ?? 300;
    final expiry = DateTime.now().add(Duration(seconds: expiresIn));

    _tokens = AuthTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiry: expiry,
    );

    await Future.wait([
      _storage.write(key: AppConstants.keyServerUrl, value: _serverUrl!),
      _storage.write(
          key: AppConstants.keyOauthClientId, value: _oauthClientId),
      _storage.write(
          key: AppConstants.keyAccessToken, value: _tokens!.accessToken),
      _storage.write(
          key: AppConstants.keyRefreshToken, value: _tokens!.refreshToken),
      _storage.write(
          key: AppConstants.keyTokenExpiry, value: expiry.toIso8601String()),
    ]);
  }
}
