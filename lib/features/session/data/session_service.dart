/// Per-UMO custom rules. Mirrors `views/SessionManagementPage.vue`. A rule
/// is a `umo` (`platform:message_type:session_id`) -> a map of
/// `rule_key -> rule_value` overrides:
///
///   session_service_config         -> {custom_name, persona_id, enable_session, ...}
///   provider_perf_chat_completion  -> provider id (string)
///   provider_perf_speech_to_text   -> provider id (string)
///   provider_perf_text_to_speech   -> provider id (string)
///   session_plugin_config          -> {enabled_plugins, disabled_plugins}
///   kb_config                      -> {kb_ids, top_k, enable_rerank}
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class SessionRule {
  final Map<String, dynamic> raw;
  SessionRule(this.raw);

  String get umo => (raw['umo'] ?? '').toString();
  String get platform =>
      (raw['platform'] ?? umo.split(':').firstOrNull ?? '').toString();
  String get messageType {
    final s = raw['message_type'];
    if (s is String) return s;
    final parts = umo.split(':');
    return parts.length > 1 ? parts[1] : '';
  }

  String get sessionId {
    final s = raw['session_id'];
    if (s is String) return s;
    final parts = umo.split(':');
    return parts.length > 2 ? parts.skip(2).join(':') : '';
  }

  Map<String, dynamic> get rules {
    final r = raw['rules'];
    if (r is Map) return Map<String, dynamic>.from(r);
    return const {};
  }
}

class SessionRulesPage {
  final List<SessionRule> rules;
  final int total;
  final List<String> availablePersonas;
  final List<Map<String, dynamic>> availableChatProviders;
  final List<Map<String, dynamic>> availableSttProviders;
  final List<Map<String, dynamic>> availableTtsProviders;
  final List<Map<String, dynamic>> availablePlugins;
  final List<Map<String, dynamic>> availableKbs;

  SessionRulesPage({
    required this.rules,
    required this.total,
    required this.availablePersonas,
    required this.availableChatProviders,
    required this.availableSttProviders,
    required this.availableTtsProviders,
    required this.availablePlugins,
    required this.availableKbs,
  });
}

class SessionService {
  SessionService(this._dio);
  final Dio _dio;

  Future<SessionRulesPage> listRules({
    int page = 1,
    int pageSize = 50,
    String search = '',
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/session/list-rule',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (search.isNotEmpty) 'search': search,
        },
      );
      final data = res.data;
      if (data is! Map) throw ApiException(kind: ApiErrorKind.unknown, message: 'bad shape');
      List<Map<String, dynamic>> asList(dynamic v) {
        if (v is! List) return const [];
        return v
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      List<String> asStrs(dynamic v) {
        if (v is! List) return const [];
        return v.map((e) => e?.toString() ?? '').toList();
      }
      return SessionRulesPage(
        rules: asList(data['rules'])
            .map((m) => SessionRule(Map<String, dynamic>.from(m)))
            .toList(),
        total: (data['total'] as num?)?.toInt() ?? 0,
        availablePersonas: asStrs(data['available_personas']),
        availableChatProviders: asList(data['available_chat_providers']),
        availableSttProviders: asList(data['available_stt_providers']),
        availableTtsProviders: asList(data['available_tts_providers']),
        availablePlugins: asList(data['available_plugins']),
        availableKbs: asList(data['available_kbs']),
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<List<String>> activeUmos() async {
    try {
      final res = await _dio.get<dynamic>('/api/session/active-umos');
      final data = res.data;
      if (data is Map && data['umos'] is List) {
        return (data['umos'] as List).map((e) => e.toString()).toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updateRule({
    required String umo,
    required String ruleKey,
    required dynamic ruleValue,
  }) =>
      _post('/api/session/update-rule', {
        'umo': umo,
        'rule_key': ruleKey,
        'rule_value': ruleValue,
      });

  /// Delete a single rule_key under [umo], or every rule for that UMO when
  /// [ruleKey] is null (server interprets missing rule_key as full delete).
  Future<void> deleteRule({required String umo, String? ruleKey}) => _post(
      '/api/session/delete-rule',
      {'umo': umo, 'rule_key': ?ruleKey});

  Future<void> batchDelete(List<String> umos) =>
      _post('/api/session/batch-delete-rule', {'umos': umos});

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(path, data: body);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(ref.watch(apiClientProvider)),
);

final sessionRulesProvider =
    FutureProvider<SessionRulesPage>((ref) async {
  return ref.watch(sessionServiceProvider).listRules();
});
