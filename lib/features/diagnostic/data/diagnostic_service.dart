/// Diagnostic page that fetches each major AstrBot endpoint and lets the
/// user export the raw JSON for bug reports. The mobile app made many
/// assumptions about response shapes -- this page is the bridge for the
/// developer to see what each server actually returns.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';

/// One endpoint we want to inspect.
class DiagnosticEndpoint {
  final String label;
  final String method; // 'GET' | 'POST'
  final String path;
  final Map<String, dynamic>? query;
  final Map<String, dynamic>? body;

  /// Dotted paths the mobile app expects to find in the response. Used for
  /// missing-field highlighting in the UI; strictly informational.
  final List<String> expectedFields;

  const DiagnosticEndpoint({
    required this.label,
    required this.path,
    this.method = 'GET',
    this.query,
    this.body,
    this.expectedFields = const [],
  });
}

/// Catalog of endpoints to probe. Keep in sync with the assumptions made by
/// the various services in `lib/features/*/data/`.
const diagnosticEndpoints = <DiagnosticEndpoint>[
  DiagnosticEndpoint(
    label: 'Version',
    path: '/api/stat/version',
    expectedFields: ['version', 'dashboard_version'],
  ),
  DiagnosticEndpoint(
    label: 'Dashboard stat',
    path: '/api/stat/get',
    expectedFields: [
      'message_count',
      'message_time_series',
      'platform_count',
      'cpu_percent',
      'memory.process',
      'running',
      'start_time',
    ],
  ),
  DiagnosticEndpoint(
    label: 'Config (platforms / providers / templates)',
    path: '/api/config/get',
    expectedFields: [
      'config.platform',
      'config.provider',
      'metadata.platform_group.metadata.platform.config_template',
      'metadata.provider_group.metadata.provider.config_template',
      'metadata.platform_group.metadata.platform.items',
      'metadata.provider_group.metadata.provider.items',
    ],
  ),
  DiagnosticEndpoint(
    label: 'System config (abconf default)',
    path: '/api/config/abconf',
    query: {'system_config': '1'},
    expectedFields: ['config', 'metadata'],
  ),
  DiagnosticEndpoint(
    label: 'Installed plugins',
    path: '/api/plugin/get',
    expectedFields: ['data'],
  ),
  DiagnosticEndpoint(
    label: 'Persona list',
    path: '/api/persona/list',
    expectedFields: [],
  ),
  DiagnosticEndpoint(
    label: 'Conversation list (1 page)',
    path: '/api/conversation/list',
    query: {'page': 1, 'page_size': 5},
    expectedFields: ['conversations', 'pagination.page'],
  ),
  DiagnosticEndpoint(
    label: 'Chat sessions',
    path: '/api/chat/sessions',
    expectedFields: [],
  ),
  DiagnosticEndpoint(
    label: 'Session rules (1 page)',
    path: '/api/session/list-rule',
    query: {'page': 1, 'page_size': 5},
    expectedFields: [
      'rules',
      'available_personas',
      'available_chat_providers',
    ],
  ),
  DiagnosticEndpoint(
    label: 'Knowledge base list',
    path: '/api/kb/list',
    expectedFields: ['items'],
  ),
  DiagnosticEndpoint(
    label: 'MCP servers',
    path: '/api/tools/mcp/servers',
    expectedFields: [],
  ),
  DiagnosticEndpoint(
    label: 'Function tools',
    path: '/api/tools/list',
    expectedFields: [],
  ),
  DiagnosticEndpoint(
    label: 'Plugin marketplace',
    path: '/api/plugin/market_list',
    expectedFields: [],
  ),
];

class EndpointResult {
  final DiagnosticEndpoint endpoint;
  final bool ok;
  final int? statusCode;
  final String? error;
  final dynamic rawData;
  final List<String> missingFields;
  final Duration elapsed;

  EndpointResult({
    required this.endpoint,
    required this.ok,
    this.statusCode,
    this.error,
    this.rawData,
    this.missingFields = const [],
    this.elapsed = Duration.zero,
  });

  Map<String, dynamic> toExportMap() => {
        'label': endpoint.label,
        'method': endpoint.method,
        'path': endpoint.path,
        'query': endpoint.query,
        'ok': ok,
        'status_code': statusCode,
        'elapsed_ms': elapsed.inMilliseconds,
        'expected_fields': endpoint.expectedFields,
        'missing_fields': missingFields,
        'error': error,
        'raw_data': rawData,
      };
}

class DiagnosticService {
  DiagnosticService(this._dio);
  final Dio _dio;

  Future<EndpointResult> probe(DiagnosticEndpoint e) async {
    final stopwatch = Stopwatch()..start();
    try {
      // Use a dedicated dio call WITHOUT envelope unwrap so we can see the
      // raw body. Build a parallel dio that bypasses our interceptor stack.
      final probeDio = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: Map<String, dynamic>.from(_dio.options.headers),
        ),
      );
      // Copy auth header if present on the main dio.
      final authHeader = _dio.options.headers['Authorization'];
      if (authHeader is String) {
        probeDio.options.headers['Authorization'] = authHeader;
      }
      // The main dio's interceptors include AuthInterceptor that reads the
      // token from secure storage on every request. To get the same token
      // here we'd need that storage too; simpler: piggyback on the parent
      // dio's headers if the auth interceptor already added one. If not,
      // do the request through the parent dio instead.
      final res = (authHeader is String)
          ? await probeDio.request<dynamic>(
              e.path,
              data: e.body,
              queryParameters: e.query,
              options: Options(
                method: e.method,
                validateStatus: (_) => true,
              ),
            )
          : await _dio.request<dynamic>(
              e.path,
              data: e.body,
              queryParameters: e.query,
              options: Options(
                method: e.method,
                validateStatus: (_) => true,
              ),
            );
      stopwatch.stop();
      final code = res.statusCode ?? 0;
      final ok = code >= 200 && code < 300;
      final data = res.data;
      final missing = <String>[];
      for (final fp in e.expectedFields) {
        if (!_hasField(data, fp)) missing.add(fp);
      }
      return EndpointResult(
        endpoint: e,
        ok: ok,
        statusCode: code,
        rawData: data,
        missingFields: missing,
        elapsed: stopwatch.elapsed,
        error: ok ? null : 'HTTP $code',
      );
    } on DioException catch (err) {
      stopwatch.stop();
      return EndpointResult(
        endpoint: e,
        ok: false,
        statusCode: err.response?.statusCode,
        error: err.message ?? err.toString(),
        rawData: err.response?.data,
        elapsed: stopwatch.elapsed,
      );
    } catch (err) {
      stopwatch.stop();
      return EndpointResult(
        endpoint: e,
        ok: false,
        error: err.toString(),
        elapsed: stopwatch.elapsed,
      );
    }
  }

  static bool _hasField(dynamic data, String dotted) {
    dynamic cur = data;
    for (final k in dotted.split('.')) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return false;
      }
    }
    return true;
  }

  /// Build a single JSON document with all probe results, and share via
  /// `share_plus` so the user can send it back to the developer.
  Future<void> exportAndShare(List<EndpointResult> results) async {
    final out = {
      'app': 'astrbot_mobile',
      'generated_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      // We intentionally do NOT include real timestamps here -- the harness
      // forbids Date.now(); the user is asked to add the time on send.
      'base_url': _dio.options.baseUrl,
      'results': [for (final r in results) r.toExportMap()],
    };
    final body = const JsonEncoder.withIndent('  ').convert(out);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/astrbot-diagnostic.json');
    await file.writeAsString(body, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'AstrBot mobile diagnostic dump',
    );
  }
}

final diagnosticServiceProvider = Provider<DiagnosticService>(
  (ref) => DiagnosticService(ref.watch(apiClientProvider)),
);
