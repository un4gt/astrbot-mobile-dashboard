/// Probe endpoint for SetupScreen "test connection" button.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';

class SetupController {
  SetupController();

  /// Issues GET /api/stat/version against the candidate URL. Returns true
  /// only if the URL is reachable and responds with HTTP 2xx -- a 401 also
  /// counts because some AstrBot endpoints require auth but proves a server
  /// is listening. Throws [ApiException] on transport failure.
  Future<bool> testConnection(String candidate) async {
    final cleaned = candidate.trim().replaceAll(RegExp(r'/+$'), '');
    final probe = Dio(BaseOptions(
      baseUrl: cleaned,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    try {
      final res = await probe.get<dynamic>(
        '/api/stat/version',
        options: Options(validateStatus: (_) => true),
      );
      // 2xx and 401 both prove a server is there.
      final code = res.statusCode ?? 0;
      return code == 200 || code == 401;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      probe.close(force: true);
    }
  }
}

final setupControllerProvider =
    Provider<SetupController>((ref) => SetupController());
