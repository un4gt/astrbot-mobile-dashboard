/// Conversation history endpoints. Mirrors `views/ConversationPage.vue`.
///
/// Endpoints:
///   GET  /api/conversation/list      ?page=&page_size=&platforms=&message_types=&search=&exclude_ids=&exclude_platforms=
///   POST /api/conversation/detail    {user_id, cid} -&gt; {history: '...json...', ...}
///   POST /api/conversation/update    {user_id, cid, title}            -- edit metadata
///   POST /api/conversation/update_history {user_id, cid, history}     -- replace messages
///   POST /api/conversation/delete    {user_id, cid}                   -- single
///   POST /api/conversation/delete    {conversations: [{user_id,cid}]} -- batch
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class ConversationSummary {
  final Map<String, dynamic> raw;
  ConversationSummary(this.raw);

  String get userId => (raw['user_id'] ?? '').toString();
  String get cid => (raw['cid'] ?? '').toString();
  String get title =>
      (raw['title'] ?? raw['summary'] ?? '(untitled)').toString();
  String? get personaId => raw['persona_id']?.toString();
  String? get platformId => raw['platform_id']?.toString();
  String? get messageType => raw['message_type']?.toString();
  int? get updatedAt =>
      (raw['updated_at'] as num?)?.toInt() ??
      (raw['last_active'] as num?)?.toInt() ??
      (raw['created_at'] as num?)?.toInt();

  /// Human-readable session origin lifted from `parseSessionId(user_id)`.
  /// `user_id` is typically `<platformId>:<messageType>:<sessionId>`.
  ({String platform, String messageType, String sessionId}) parseSession() {
    final parts = userId.split(':');
    if (parts.length >= 3) {
      return (
        platform: parts[0],
        messageType: parts[1],
        sessionId: parts.skip(2).join(':'),
      );
    }
    return (platform: '?', messageType: '?', sessionId: userId);
  }
}

class ConversationListPage {
  final List<ConversationSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  ConversationListPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });
}

class ConversationDetail {
  final List<Map<String, dynamic>> history;
  ConversationDetail(this.history);
}

class ConversationService {
  ConversationService(this._dio);
  final Dio _dio;

  Future<ConversationListPage> list({
    int page = 1,
    int pageSize = 20,
    List<String> platforms = const [],
    List<String> messageTypes = const [],
    String? search,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/conversation/list',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (platforms.isNotEmpty) 'platforms': platforms.join(','),
          if (messageTypes.isNotEmpty) 'message_types': messageTypes.join(','),
          if (search != null && search.isNotEmpty) 'search': search,
          'exclude_ids': 'astrbot',
          'exclude_platforms': 'webchat',
        },
      );
      final data = res.data;
      final convs = data is Map ? data['conversations'] : null;
      final pagination = data is Map ? data['pagination'] : null;
      return ConversationListPage(
        items: (convs is List)
            ? convs
                .whereType<Map>()
                .map((m) => ConversationSummary(Map<String, dynamic>.from(m)))
                .toList()
            : const [],
        page: pagination is Map ? (pagination['page'] as num?)?.toInt() ?? page : page,
        pageSize: pagination is Map
            ? (pagination['page_size'] as num?)?.toInt() ?? pageSize
            : pageSize,
        total: pagination is Map ? (pagination['total'] as num?)?.toInt() ?? 0 : 0,
        totalPages: pagination is Map
            ? (pagination['total_pages'] as num?)?.toInt() ?? 1
            : 1,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<ConversationDetail> detail({
    required String userId,
    required String cid,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/conversation/detail',
        data: {'user_id': userId, 'cid': cid},
      );
      final data = res.data;
      final raw = data is Map ? data['history'] : null;
      List<Map<String, dynamic>> history;
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          history = decoded is List
              ? decoded
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList()
              : const [];
        } catch (_) {
          history = const [];
        }
      } else if (raw is List) {
        history = raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else {
        history = const [];
      }
      return ConversationDetail(history);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updateTitle({
    required String userId,
    required String cid,
    required String title,
  }) =>
      _post('/api/conversation/update', {
        'user_id': userId,
        'cid': cid,
        'title': title,
      });

  Future<void> deleteOne({required String userId, required String cid}) =>
      _post('/api/conversation/delete', {'user_id': userId, 'cid': cid});

  Future<({int deleted, int failed})> deleteBatch(
      List<({String userId, String cid})> items) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/conversation/delete',
        data: {
          'conversations': [
            for (final it in items) {'user_id': it.userId, 'cid': it.cid},
          ],
        },
      );
      final data = res.data;
      return (
        deleted: data is Map
            ? (data['deleted_count'] as num?)?.toInt() ?? items.length
            : items.length,
        failed:
            data is Map ? (data['failed_count'] as num?)?.toInt() ?? 0 : 0,
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

final conversationServiceProvider = Provider<ConversationService>(
  (ref) => ConversationService(ref.watch(apiClientProvider)),
);
