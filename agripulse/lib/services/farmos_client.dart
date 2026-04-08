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

  String get _serverUrl =>
      _authService.serverUrl ??
      (throw StateError('Server URL is not configured. Please log in first.'));
  String get _baseUrl => '$_serverUrl/api';

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
  ///
  /// When [include] is specified, the related resources are resolved into each
  /// data item under a synthetic `_included` key so callers can access them
  /// without a second round-trip.
  Future<List<Map<String, dynamic>>> getCollection(
    String resourceType, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/$resourceType',
      queryParameters: queryParameters,
    );
    final data =
        (response.data['data'] as List).cast<Map<String, dynamic>>();

    final rawIncluded = response.data['included'] as List?;
    if (rawIncluded != null && rawIncluded.isNotEmpty) {
      final includedById = <String, Map<String, dynamic>>{
        for (final item in rawIncluded.cast<Map<String, dynamic>>())
          '${item['type']}:${item['id']}': item,
      };
      for (final item in data) {
        item['_included'] = includedById;
      }
    }

    return data;
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
    var requestPayload = _sanitizePayload(resourceType, payload);
    try {
      final response = await _requestWithUnknownAttributeRetries(
        resourceType: resourceType,
        payload: requestPayload,
        send: (candidatePayload) => _dio.post(
          '$_baseUrl/$resourceType',
          data: candidatePayload,
        ),
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e));
    }
  }

  /// PATCH an existing JSON:API resource.
  Future<Map<String, dynamic>> updateResource(
    String resourceType,
    String id,
    Map<String, dynamic> payload,
  ) async {
    var requestPayload = _sanitizePayload(resourceType, payload);
    try {
      final response = await _requestWithUnknownAttributeRetries(
        resourceType: resourceType,
        payload: requestPayload,
        send: (candidatePayload) => _dio.patch(
          '$_baseUrl/$resourceType/$id',
          data: candidatePayload,
        ),
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e));
    }
  }

  /// DELETE a JSON:API resource.
  Future<void> deleteResource(String resourceType, String id) async {
    await _dio.delete('$_baseUrl/$resourceType/$id');
  }

  /// GET a custom (non-JSON:API) endpoint, returning the decoded JSON body.
  Future<Map<String, dynamic>> getCustom(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _dio.get(
      '$_serverUrl$path',
      queryParameters: queryParameters,
      options: Options(headers: {
        'Accept': 'application/json',
      }),
    );
    return response.data as Map<String, dynamic>;
  }

  String _formatDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ??
          data['error'] ??
          data['title'] ??
          (data['errors'] is List && (data['errors'] as List).isNotEmpty
              ? (data['errors'] as List).first.toString()
              : null);
      if (message != null) {
        return 'HTTP ${status ?? 'error'}: $message';
      }
    }
    return 'HTTP ${status ?? 'error'}: ${e.message ?? 'Request failed'}';
  }

  Map<String, dynamic> _sanitizePayload(
    String resourceType,
    Map<String, dynamic> payload,
  ) {
    return payload;
  }

  Future<Response<dynamic>> _requestWithUnknownAttributeRetries({
    required String resourceType,
    required Map<String, dynamic> payload,
    required Future<Response<dynamic>> Function(
      Map<String, dynamic> candidatePayload,
    ) send,
  }) async {
    var candidate = _sanitizePayload(resourceType, payload);

    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        return await send(candidate);
      } on DioException catch (e) {
        final attr = _extractUnknownAttribute(e);
        if (attr == null) rethrow;

        final updated = _removeAttribute(candidate, attr);
        if (updated == null) rethrow;
        candidate = updated;
      }
    }

    throw DioException(
      requestOptions: RequestOptions(path: '$_baseUrl/$resourceType'),
      error: 'Request failed after removing unsupported attributes.',
    );
  }

  Map<String, dynamic>? _removeAttribute(
    Map<String, dynamic> payload,
    String attr,
  ) {
    final cloned = Map<String, dynamic>.from(payload);
    final data = cloned['data'];
    if (data is! Map<String, dynamic>) return null;

    final clonedData = Map<String, dynamic>.from(data);
    final attributes = clonedData['attributes'];
    if (attributes is! Map<String, dynamic>) return null;

    final clonedAttributes = Map<String, dynamic>.from(attributes);
    if (!clonedAttributes.containsKey(attr)) return null;
    clonedAttributes.remove(attr);

    clonedData['attributes'] = clonedAttributes;
    cloned['data'] = clonedData;
    return cloned;
  }

  String? _extractUnknownAttribute(DioException error) {
    final data = error.response?.data;
    if (data is! Map<String, dynamic>) return null;
    final detail = data['detail']?.toString();
    if (detail == null) return null;

    final match = RegExp(r'attribute ([a-zA-Z0-9_]+) does not exist')
        .firstMatch(detail);
    return match?.group(1);
  }
}
