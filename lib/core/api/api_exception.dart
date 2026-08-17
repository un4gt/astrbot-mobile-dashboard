/// Typed exception representing AstrBot API failures.
library;

import 'package:dio/dio.dart';

enum ApiErrorKind {
  network, // unreachable / timeout
  unauthorized, // 401
  server, // {status:'error', ...} envelope
  unknown,
}

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      return ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Session expired',
        statusCode: status,
        cause: e,
      );
    }
    final t = e.type;
    if (t == DioExceptionType.connectionError ||
        t == DioExceptionType.connectionTimeout ||
        t == DioExceptionType.receiveTimeout ||
        t == DioExceptionType.sendTimeout) {
      return ApiException(
        kind: ApiErrorKind.network,
        message: e.message ?? 'Network unreachable',
        statusCode: status,
        cause: e,
      );
    }
    final body = e.response?.data;
    if (body is Map && body['message'] is String) {
      return ApiException(
        kind: ApiErrorKind.server,
        message: body['message'] as String,
        statusCode: status,
        cause: e,
      );
    }
    return ApiException(
      kind: ApiErrorKind.unknown,
      message: e.message ?? 'Unknown error',
      statusCode: status,
      cause: e,
    );
  }

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
