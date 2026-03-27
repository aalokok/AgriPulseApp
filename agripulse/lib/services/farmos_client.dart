import 'package:dio/dio.dart';

import 'auth_service.dart';

/// Dio-based HTTP client for the farmOS JSON:API, with automatic token
/// injection and 401 → refresh → retry logic.
class FarmosClient {
  final AuthService _authService;
  late final Dio _dio;

  FarmosClient(this._authService) {
    _dio = Dio(BaseOptions(
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  String get _baseUrl => '${_authService.serverUrl}/api';

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final tokens = _authService.tokens;
    if (tokens != null) {
      if (tokens.isExpired) {
        try {
          await _authService.refreshAccessToken();
        } catch (e) {
          return handler.reject(DioException(
            requestOptions: options,
            error: 'Token refresh failed',
          ));
        }
      }
      options.headers['Authorization'] =
          'Bearer ${_authService.tokens!.accessToken}';
    }
    handler.next(options);
  }

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await _authService.refreshAccessToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] =
            'Bearer ${_authService.tokens!.accessToken}';
        final response = await _dio.fetch(opts);
        return handler.resolve(response);
      } catch (_) {
        // Refresh failed — propagate the original 401
      }
    }
    handler.next(err);
  }

  // ── JSON:API helpers ──────────────────────────────────────────────────

  /// GET a JSON:API collection, returning the `data` array.
  Future<List<Map<String, dynamic>>> getCollection(
    String resourceType, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/$resourceType',
      queryParameters: queryParameters,
    );
    final data = response.data['data'];
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// GET a single JSON:API resource, returning the `data` object.
  Future<Map<String, dynamic>> getResource(
    String resourceType,
    String id,
  ) async {
    final response = await _dio.get('$_baseUrl/$resourceType/$id');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// POST a new JSON:API resource, returning the created `data` object.
  Future<Map<String, dynamic>> createResource(
    String resourceType,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '$_baseUrl/$resourceType',
      data: payload,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// PATCH an existing JSON:API resource.
  Future<Map<String, dynamic>> updateResource(
    String resourceType,
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      '$_baseUrl/$resourceType/$id',
      data: payload,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// DELETE a JSON:API resource.
  Future<void> deleteResource(String resourceType, String id) async {
    await _dio.delete('$_baseUrl/$resourceType/$id');
  }
}
