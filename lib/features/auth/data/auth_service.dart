/// Login + account edit endpoints. Mirrors `dashboard/src/stores/auth.ts`
/// and the account dialog in `vertical-header/VerticalHeader.vue`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/md5_hash.dart';

class AuthLoginResult {
  final String username;
  final String token;
  final bool changePwdHint;
  AuthLoginResult({
    required this.username,
    required this.token,
    required this.changePwdHint,
  });

  factory AuthLoginResult.fromMap(Map<String, dynamic> data) {
    return AuthLoginResult(
      username: (data['username'] ?? '').toString(),
      token: (data['token'] ?? '').toString(),
      changePwdHint:
          data['change_pwd_hint'] == true || data['change_pwd_hint'] == 'true',
    );
  }
}

class AuthService {
  AuthService(this._dio);
  final Dio _dio;

  /// POST /api/auth/login. Password is MD5-hashed before send to match the
  /// dashboard's js-md5 behavior.
  Future<AuthLoginResult> login({
    required String username,
    required String plainPassword,
  }) async {
    try {
      final hashed = md5Hash(plainPassword);
      final res = await _dio.post<dynamic>(
        '/api/auth/login',
        data: {'username': username, 'password': hashed},
      );
      // EnvelopeInterceptor unwrapped {status, data} so res.data IS data here.
      // For login we MIGHT receive the raw envelope when status=='ok' is
      // present (intercepted) -- in either case res.data is the unwrapped map.
      final data = res.data;
      if (data is Map) {
        return AuthLoginResult.fromMap(Map<String, dynamic>.from(data));
      }
      throw ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Unexpected login response',
      );
    } on DioException catch (e) {
      // The envelope interceptor wraps server errors as DioException with
      // ApiException in `error`.
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  /// POST /api/auth/account/edit. Both current and new passwords are
  /// md5-hashed; new_username is optional (server falls back to current).
  Future<void> editAccount({
    required String currentPlainPassword,
    String? newPlainPassword,
    String? newUsername,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/api/auth/account/edit',
        data: {
          'password': md5Hash(currentPlainPassword),
          if (newPlainPassword != null && newPlainPassword.isNotEmpty)
            'new_password': md5Hash(newPlainPassword),
          if (newUsername != null && newUsername.isNotEmpty)
            'new_username': newUsername,
        },
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});
