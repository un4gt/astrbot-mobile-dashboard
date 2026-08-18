/// Plugin / extension API. Mirrors the endpoints used in
/// `views/ExtensionPage.vue` plus the marketplace fetch logic from
/// `stores/common.js`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

/// Shape returned by `/api/plugin/get`. We keep the raw map and expose only
/// the fields the list view needs.
class InstalledPlugin {
  final Map<String, dynamic> raw;
  InstalledPlugin(this.raw);

  String get name => (raw['name'] ?? '').toString();
  String get version => (raw['version'] ?? '').toString();
  String get author => (raw['author'] ?? '').toString();
  String get description => (raw['desc'] ?? raw['description'] ?? '').toString();
  String? get repo => raw['repo']?.toString();

  /// Server-side logo URL (`/api/file/<token>`) when the plugin ships one.
  String? get logo {
    final v = raw['logo']?.toString();
    return (v != null && v.isNotEmpty) ? v : null;
  }

  bool get activated =>
      raw['activated'] == true || raw['enable'] == true || raw['enabled'] == true;
  bool get reserved => raw['reserved'] == true; // built-in plugins
}

class MarketPlugin {
  final Map<String, dynamic> raw;
  MarketPlugin(this.raw);

  String get name => (raw['name'] ?? '').toString();
  String get version => (raw['version'] ?? '').toString();
  String get author => (raw['author'] ?? '').toString();
  String get description => (raw['desc'] ?? raw['description'] ?? '').toString();
  String? get repo => raw['repo']?.toString();
  String? get logo => raw['logo']?.toString();
  List<String> get tags {
    final t = raw['tags'];
    if (t is List) return t.map((e) => e.toString()).toList();
    return const [];
  }
}

class PluginService {
  PluginService(this._dio);
  final Dio _dio;

  Future<List<InstalledPlugin>> listInstalled() async {
    try {
      final res = await _dio.get<dynamic>('/api/plugin/get');
      final data = res.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((m) => InstalledPlugin(Map<String, dynamic>.from(m)))
            .toList();
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => InstalledPlugin(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<List<MarketPlugin>> listMarket({bool forceRefresh = false}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/plugin/market_list',
        queryParameters: forceRefresh ? {'force_refresh': 'true'} : null,
      );
      final data = res.data;
      // Server wraps result under {data: {...}} or {data: [...]} variants.
      List list;
      if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else if (data is Map && data['data'] is Map) {
        // some versions group plugins by category -- flatten.
        list = (data['data'] as Map).values
            .whereType<List>()
            .expand((l) => l)
            .toList();
      } else if (data is List) {
        list = data;
      } else {
        return const [];
      }
      return list
          .whereType<Map>()
          .map((m) => MarketPlugin(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> setActivated(String name, bool active) =>
      _post(active ? '/api/plugin/on' : '/api/plugin/off', {'name': name});

  Future<void> reload(String name) =>
      _post('/api/plugin/reload', {'name': name});

  Future<void> uninstall(String name,
          {bool deleteConfig = false, bool deleteData = false}) =>
      _post('/api/plugin/uninstall', {
        'name': name,
        'delete_config': deleteConfig,
        'delete_data': deleteData,
      });

  Future<void> update(String name, {String proxy = ''}) =>
      _post('/api/plugin/update', {'name': name, 'proxy': proxy});

  Future<void> installFromUrl(String url, {String proxy = ''}) =>
      _post('/api/plugin/install', {'url': url, 'proxy': proxy});

  /// Upload a local plugin archive (typically a `.zip`) via multipart.
  /// Mirrors `/api/plugin/install-upload` from `ExtensionPage.vue` (line ~547).
  /// Returns server data on success (often `{name, repo}`) or null.
  Future<Map<String, dynamic>?> installFromUpload({
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post<dynamic>(
        '/api/plugin/install-upload',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onProgress,
      );
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  /// Fetch plugin README markdown via `/api/plugin/readme?name=<n>`.
  /// Returns the markdown body; throws on failure.
  Future<String> fetchReadme(String name) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/plugin/readme',
        queryParameters: {'name': name},
      );
      final data = res.data;
      if (data is Map && data['content'] is String) {
        return data['content'] as String;
      }
      if (data is String) return data;
      throw ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Unexpected README response shape.',
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>?> getPluginConfig(String name) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/config/get',
        queryParameters: {'plugin_name': name},
      );
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> savePluginConfig(
      String name, Map<String, dynamic> config) async {
    try {
      await _dio.post<dynamic>(
        '/api/config/plugin/update',
        queryParameters: {'plugin_name': name},
        data: config,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(path, data: body);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final pluginServiceProvider =
    Provider<PluginService>((ref) => PluginService(ref.watch(apiClientProvider)));

final installedPluginsProvider =
    FutureProvider<List<InstalledPlugin>>((ref) async {
  return ref.watch(pluginServiceProvider).listInstalled();
});

final pluginMarketProvider =
    FutureProvider<List<MarketPlugin>>((ref) async {
  return ref.watch(pluginServiceProvider).listMarket();
});
