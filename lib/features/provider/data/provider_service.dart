/// Provider CRUD + availability check.
///
/// Endpoints:
///   POST /api/config/provider/{new, update, delete}
///   GET  `/api/config/provider/check_one?id=<id>`
///
/// `provider_type` mapping (legacy `type` -&gt; new capability bucket) is
/// embedded here so the list view can group providers consistently with
/// `ProviderPage.vue` even when an old provider object lacks
/// `provider_type`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

/// Stable list of provider capability tabs used both for grouping and for
/// the "add provider" template picker.
const providerTypes = <String>[
  'chat_completion',
  'agent_runner',
  'speech_to_text',
  'text_to_speech',
  'embedding',
  'rerank',
];

/// Legacy `type` -> capability bucket. Mirrors
/// `oldVersionProviderTypeMapping` in `ProviderPage.vue`.
const _legacyTypeToCapability = <String, String>{
  'openai_chat_completion': 'chat_completion',
  'anthropic_chat_completion': 'chat_completion',
  'googlegenai_chat_completion': 'chat_completion',
  'zhipu_chat_completion': 'chat_completion',
  'dashscope': 'chat_completion',
  'dify': 'agent_runner',
  'coze': 'agent_runner',
  'openai_whisper_api': 'speech_to_text',
  'openai_whisper_selfhost': 'speech_to_text',
  'sensevoice_stt_selfhost': 'speech_to_text',
  'openai_tts_api': 'text_to_speech',
  'edge_tts': 'text_to_speech',
  'gsvi_tts_api': 'text_to_speech',
  'fishaudio_tts_api': 'text_to_speech',
  'dashscope_tts': 'text_to_speech',
  'azure_tts': 'text_to_speech',
  'minimax_tts_api': 'text_to_speech',
  'volcengine_tts': 'text_to_speech',
};

/// Returns the capability bucket for a provider object or null when neither
/// `provider_type` nor a known legacy `type` is present (caller should put
/// these under "others").
String? capabilityOf(Map<String, dynamic> provider) {
  final pt = provider['provider_type'];
  if (pt is String && pt.isNotEmpty) return pt;
  final t = provider['type'];
  if (t is String) return _legacyTypeToCapability[t];
  return null;
}

class ProviderStatus {
  final String id;
  final String name;
  final String status; // 'available' | 'unavailable' | 'pending'
  final String? error;
  ProviderStatus({
    required this.id,
    required this.name,
    required this.status,
    this.error,
  });

  factory ProviderStatus.fromMap(Map<String, dynamic> m) => ProviderStatus(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? m['id'] ?? '').toString(),
        status: (m['status'] ?? 'pending').toString(),
        error: m['error']?.toString(),
      );
}

class ProviderService {
  ProviderService(this._dio);
  final Dio _dio;

  Future<void> create(Map<String, dynamic> config) =>
      _post('/api/config/provider/new', config);

  Future<void> update(String id, Map<String, dynamic> config) =>
      _post('/api/config/provider/update', {'id': id, 'config': config});

  Future<void> delete(String id) =>
      _post('/api/config/provider/delete', {'id': id});

  Future<ProviderStatus> checkOne(String id) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/config/provider/check_one',
        queryParameters: {'id': id},
      );
      final data = res.data;
      if (data is Map) {
        return ProviderStatus.fromMap(Map<String, dynamic>.from(data));
      }
      return ProviderStatus(id: id, name: id, status: 'unavailable');
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

final providerServiceProvider = Provider<ProviderService>(
    (ref) => ProviderService(ref.watch(apiClientProvider)));
