/// Version info, update check, and restart for the AstrBot core.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class VersionInfo {
  final String version;
  final String dashboardVersion;
  final bool needMigration;
  final bool changePwdHint;
  VersionInfo({
    required this.version,
    required this.dashboardVersion,
    required this.needMigration,
    required this.changePwdHint,
  });

  factory VersionInfo.fromMap(Map raw) => VersionInfo(
        version: (raw['version'] ?? '').toString(),
        dashboardVersion: (raw['dashboard_version'] ?? '').toString(),
        needMigration: raw['need_migration'] == true,
        changePwdHint: raw['change_pwd_hint'] == true,
      );
}

class UpdateInfo {
  final bool hasNewVersion;
  final bool dashboardHasNewVersion;
  final String message;
  UpdateInfo({
    required this.hasNewVersion,
    required this.dashboardHasNewVersion,
    required this.message,
  });
}

class SystemService {
  SystemService(this._dio);
  final Dio _dio;

  Future<VersionInfo> version() async {
    try {
      final res = await _dio.get<dynamic>('/api/stat/version');
      final data = res.data;
      if (data is Map) {
        return VersionInfo.fromMap(Map<String, dynamic>.from(data));
      }
      return VersionInfo(
        version: '-',
        dashboardVersion: '-',
        needMigration: false,
        changePwdHint: false,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<UpdateInfo> checkUpdate() async {
    try {
      final res = await _dio.get<dynamic>('/api/update/check');
      final data = res.data;
      if (data is Map) {
        return UpdateInfo(
          hasNewVersion: data['has_new_version'] == true,
          dashboardHasNewVersion: data['dashboard_has_new_version'] == true,
          message: (data['message'] ?? '').toString(),
        );
      }
      return UpdateInfo(
        hasNewVersion: false,
        dashboardHasNewVersion: false,
        message: '',
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> restartCore() async {
    try {
      await _dio.post<dynamic>('/api/stat/restart-core');
    } on DioException catch (e) {
      // Restart may close the socket before the response is read; treat
      // unexpected disconnects as success.
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        return;
      }
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final systemServiceProvider =
    Provider<SystemService>((ref) => SystemService(ref.watch(apiClientProvider)));

final versionInfoProvider = FutureProvider<VersionInfo>((ref) async {
  ref.watch(apiClientProvider); // refresh on server-profile switch
  return ref.watch(systemServiceProvider).version();
});
