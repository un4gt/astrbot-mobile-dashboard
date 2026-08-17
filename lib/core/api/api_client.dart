/// Single Dio instance configured with the user-saved server base URL,
/// auth bearer token, and AstrBot's `{status, message, data}` envelope
/// unwrap. Mirrors `dashboard/src/main.ts` axios setup.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import '../../shared/providers/app_providers.dart';
import 'api_exception.dart';
import 'local_debug_mock.dart';

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final SecureStorage _storage;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip /api/auth/login -- no token yet.
    if (!options.path.contains('/api/auth/login')) {
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

/// Unwraps the AstrBot envelope so call-sites can use `response.data`
/// directly as the inner payload. Throws ApiException on `status == 'error'`.
class _EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map) {
      final status = body['status'];
      if (status == 'error') {
        final msg = body['message']?.toString() ?? 'Unknown server error';
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: ApiException(
              kind: ApiErrorKind.server,
              message: msg,
              statusCode: response.statusCode,
            ),
          ),
        );
        return;
      }
      if (status == 'ok' && body.containsKey('data')) {
        response.data = body['data'];
      }
    }
    handler.next(response);
  }
}

/// Provider that rebuilds whenever the saved base URL changes so the dio
/// instance always points at the right server. In local debug mode the mock
/// interceptor is installed first and no request ever reaches the network.
final apiClientProvider = Provider<Dio>((ref) {
  final base = ref.watch(baseUrlProvider) ?? '';
  final localDebug = ref.watch(localDebugProvider);
  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ));
  if (localDebug) {
    dio.interceptors.add(LocalDebugInterceptor());
  }
  dio.interceptors
    ..add(_AuthInterceptor(ref.read(secureStorageProvider)))
    ..add(_EnvelopeInterceptor());
  ref.onDispose(dio.close);
  return dio;
});
