/// Native (new) Knowledge Base service. Wraps `/api/kb/*`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class KnowledgeBase {
  final Map<String, dynamic> raw;
  KnowledgeBase(this.raw);

  String get id => (raw['kb_id'] ?? '').toString();
  String get name => (raw['kb_name'] ?? '').toString();
  String get description => (raw['description'] ?? '').toString();
  String get emojiIcon => (raw['emoji_icon'] ?? '📚').toString();
  int get documentCount => (raw['document_count'] as num?)?.toInt() ?? 0;
  int get chunkCount => (raw['chunk_count'] as num?)?.toInt() ?? 0;
  String? get embeddingProviderId => raw['embedding_provider_id']?.toString();
  String? get rerankProviderId => raw['rerank_provider_id']?.toString();
}

class RetrievalHit {
  final String content;
  final double score;
  RetrievalHit({required this.content, required this.score});
  factory RetrievalHit.fromMap(Map raw) => RetrievalHit(
        content: (raw['content'] ?? raw['text'] ?? '').toString(),
        score: (raw['score'] as num?)?.toDouble() ?? 0,
      );
}

class KbService {
  KbService(this._dio);
  final Dio _dio;

  Future<List<KnowledgeBase>> list({bool refreshStats = false}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/kb/list',
        queryParameters: refreshStats ? {'refresh_stats': 'true'} : null,
      );
      final data = res.data;
      if (data is Map && data['items'] is List) {
        return (data['items'] as List)
            .whereType<Map>()
            .map((m) => KnowledgeBase(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> create(Map<String, dynamic> body) =>
      _post('/api/kb/create', body);

  Future<void> delete(String kbId) =>
      _post('/api/kb/delete', {'kb_id': kbId});

  Future<List<RetrievalHit>> retrieve({
    required String kbId,
    required String query,
    int topK = 5,
    bool useRerank = false,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/kb/retrieve',
        data: {
          'kb_id': kbId,
          'query': query,
          'top_k': topK,
          'use_rerank': useRerank,
        },
      );
      final data = res.data;
      if (data is Map && data['hits'] is List) {
        return (data['hits'] as List)
            .whereType<Map>()
            .map((m) => RetrievalHit.fromMap(m))
            .toList();
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => RetrievalHit.fromMap(m))
            .toList();
      }
      return const [];
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

final kbServiceProvider =
    Provider<KbService>((ref) => KbService(ref.watch(apiClientProvider)));

final kbListProvider = FutureProvider<List<KnowledgeBase>>((ref) async {
  ref.watch(apiClientProvider); // refresh on server-profile switch
  return ref.watch(kbServiceProvider).list();
});
