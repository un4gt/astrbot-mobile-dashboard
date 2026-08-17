/// Reads `/api/config/get`. Re-fetched after every save so callers don't
/// have to splice locally. Mirrors the Vue dashboard pattern of always
/// going back to the source of truth.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/config_bundle.dart';

class ConfigService {
  ConfigService(this._dio);
  final Dio _dio;

  Future<ConfigBundle> getConfig() async {
    try {
      final res = await _dio.get<dynamic>('/api/config/get');
      final data = res.data;
      if (data is! Map) {
        throw ApiException(
          kind: ApiErrorKind.unknown,
          message: 'Unexpected /api/config/get response shape',
        );
      }
      final config = data['config'];
      final metadata = data['metadata'];
      return ConfigBundle(
        config: config is Map ? Map<String, dynamic>.from(config) : {},
        metadata:
            metadata is Map ? Map<String, dynamic>.from(metadata) : {},
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  /// Ids of the available config files (`/api/config/abconfs` -> info_list).
  Future<List<String>> getAbconfList() async {
    try {
      final res = await _dio.get<dynamic>('/api/config/abconfs');
      final data = res.data;
      if (data is! Map) return const [];
      final infoList = data['info_list'];
      if (infoList is! List) return const [];
      return infoList
          .whereType<Map>()
          .map((e) => e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  /// Normal (non-system) AstrBot config file, e.g. `?id=default`. Returns the
  /// CONFIG_METADATA_3 group tree (ai/platform/plugin/ext groups); item keys
  /// are dotted selectors into `config`.
  Future<ConfigBundle> getAbconf({String id = 'default'}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/config/abconf',
        queryParameters: {'id': id},
      );
      return _bundleFrom(res.data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  /// System-level config (single document). The dashboard fetches this with
  /// `?system_config=1` against `/api/config/abconf` and saves via
  /// `/api/config/astrbot/update` with `conf_id: 'default'`.
  Future<ConfigBundle> getSystemConfig() async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/config/abconf',
        queryParameters: {'system_config': '1'},
      );
      return _bundleFrom(res.data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  ConfigBundle _bundleFrom(dynamic data) {
    if (data is! Map) {
      throw ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Unexpected /api/config/abconf response shape',
      );
    }
    final config = data['config'];
    final metadata = data['metadata'];
    return ConfigBundle(
      config: config is Map ? Map<String, dynamic>.from(config) : {},
      metadata:
          metadata is Map ? Map<String, dynamic>.from(metadata) : {},
    );
  }

  /// Save the entire system config and return the server's reply message.
  /// Server typically restarts the core after a system save; the screen is
  /// expected to surface a "restarting" hint.
  Future<void> saveSystemConfig(Map<String, dynamic> config) async {
    try {
      await _dio.post<dynamic>(
        '/api/config/astrbot/update',
        data: {'config': config, 'conf_id': 'default'},
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final configServiceProvider = Provider<ConfigService>((ref) {
  return ConfigService(ref.watch(apiClientProvider));
});

/// Cached, refreshable view of the config bundle. Each Platform/Provider
/// screen watches this and triggers `ref.invalidate(configBundleProvider)`
/// after a write to refresh.
final configBundleProvider = FutureProvider<ConfigBundle>((ref) async {
  // Depend on the dio instance (which follows the active server profile) so
  // switching servers invalidates this cache instead of showing the old
  // server's config.
  ref.watch(apiClientProvider);
  return ref.watch(configServiceProvider).getConfig();
});

/// Full config-page bundle: the normal config file's metadata groups
/// (ai/platform/plugin/ext) merged with the system group
/// (`?system_config=1`), so the screen can render every tab the web
/// dashboard's 配置 page has. Falls back through the web dashboard's own
/// resolution order: `id=default` -> first entry of /config/abconfs ->
/// system-only.
final systemConfigProvider = FutureProvider<ConfigBundle>((ref) async {
  // See configBundleProvider: tie to the live dio so server switches refresh.
  ref.watch(apiClientProvider);
  final svc = ref.watch(configServiceProvider);
  ConfigBundle normal;
  try {
    normal = await svc.getAbconf();
  } on ApiException {
    try {
      final list = await svc.getAbconfList();
      final first = list.isNotEmpty ? list.first : null;
      if (first == null) rethrow;
      normal = await svc.getAbconf(id: first);
    } on ApiException {
      return svc.getSystemConfig();
    }
  }
  try {
    final system = await svc.getSystemConfig();
    return ConfigBundle(
      config: normal.config,
      metadata: {...normal.metadata, ...system.metadata},
    );
  } on ApiException {
    return normal;
  }
});
