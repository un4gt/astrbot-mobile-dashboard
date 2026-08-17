/// Chat session + message + media endpoints, plus streaming `/api/chat/send`.
///
/// Streaming chunk shapes (per `composables/useMessages.ts`):
///   `{type:'plain', data, chain_type:'normal'|'reasoning', streaming}`
///   `{type:'image', data:'[IMAGE]<filename>'}`
///   `{type:'record', data:'[RECORD]<filename>'}`
///   `{type:'update_title', session_id, data:'<new title>'}`
///   `{type:'break', streaming}`
///   `{type:'error', data}`
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class ChatSession {
  final Map<String, dynamic> raw;
  ChatSession(this.raw);

  String get id => (raw['session_id'] ?? '').toString();
  String get title {
    final dn = raw['display_name'];
    if (dn is String && dn.trim().isNotEmpty) return dn;
    return id.isEmpty ? '(untitled)' : id;
  }

  String? get updatedAt => raw['updated_at']?.toString();
  String? get platformId => raw['platform_id']?.toString();
  bool get isGroup => (raw['is_group'] as num?) == 1;
}

/// One unit emitted by the streaming chat endpoint. UI-side we accumulate
/// `plain` chunks into a growing message; image/record produce inline media.
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class StreamPlainChunk extends ChatStreamEvent {
  final String text;
  final bool reasoning;
  final bool streaming;
  StreamPlainChunk(this.text, {required this.reasoning, required this.streaming});
}

class StreamMedia extends ChatStreamEvent {
  /// 'image' or 'record'.
  final String kind;
  final String filename;
  StreamMedia({required this.kind, required this.filename});
}

class StreamTitleUpdate extends ChatStreamEvent {
  final String sessionId;
  final String title;
  StreamTitleUpdate(this.sessionId, this.title);
}

class StreamBreak extends ChatStreamEvent {
  final bool streaming;
  StreamBreak(this.streaming);
}

class StreamError extends ChatStreamEvent {
  final String message;
  StreamError(this.message);
}

class ChatService {
  ChatService(this._dio);
  final Dio _dio;

  // Sessions ---------------------------------------------------------------

  Future<List<ChatSession>> listSessions() async {
    try {
      final res = await _dio.get<dynamic>('/api/chat/sessions');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => ChatSession(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<String> createSession() async {
    try {
      final res = await _dio.get<dynamic>('/api/chat/new_session');
      final data = res.data;
      if (data is Map) return (data['session_id'] ?? '').toString();
      return '';
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await _dio.get<dynamic>(
        '/api/chat/delete_session',
        queryParameters: {'session_id': id},
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> renameSession(String id, String title) async {
    try {
      await _dio.post<dynamic>(
        '/api/chat/update_session_display_name',
        data: {'session_id': id, 'display_name': title},
      );
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  // Messages ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSessionMessages(String id) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/chat/get_session',
        queryParameters: {'session_id': id},
      );
      final data = res.data;
      if (data is Map) {
        final history = data['history'];
        if (history is List) {
          return history
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  /// Stream a chat reply. The connection holds open until the server signals
  /// the end of the response. Each yielded event tells the UI what to render.
  Stream<ChatStreamEvent> sendMessage({
    required String sessionId,
    required String text,
    List<String> imageNames = const [],
    String? audioName,
    String? selectedProvider,
    String? selectedModel,
    bool enableStreaming = true,
  }) async* {
    final body = <String, dynamic>{
      'message': text,
      'session_id': sessionId,
      'image_url': imageNames,
      'audio_url': audioName != null ? [audioName] : <String>[],
      'selected_provider': selectedProvider ?? '',
      'selected_model': selectedModel ?? '',
      'enable_streaming': enableStreaming,
    };
    final resp = await _dio.post<ResponseBody>(
      '/api/chat/send',
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        receiveTimeout: Duration.zero,
      ),
    );
    final stream = resp.data?.stream;
    if (stream == null) return;

    var buffer = '';
    await for (final bytes in stream) {
      buffer += utf8.decode(bytes, allowMalformed: true);
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final event = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 2);
        if (event.isEmpty) continue;
        // Some servers emit `data: {...}`, some emit just `{...}`.
        final payload = event.startsWith('data:')
            ? event.substring(5).trim()
            : event;
        Map<String, dynamic>? json;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) json = decoded;
        } catch (_) {
          continue;
        }
        if (json == null) continue;

        final type = json['type']?.toString();
        switch (type) {
          case 'plain':
            yield StreamPlainChunk(
              (json['data'] ?? '').toString(),
              reasoning: json['chain_type'] == 'reasoning',
              streaming: json['streaming'] == true,
            );
            break;
          case 'image':
            final raw = (json['data'] ?? '').toString();
            yield StreamMedia(
              kind: 'image',
              filename: raw.replaceFirst('[IMAGE]', ''),
            );
            break;
          case 'record':
            final raw = (json['data'] ?? '').toString();
            yield StreamMedia(
              kind: 'record',
              filename: raw.replaceFirst('[RECORD]', ''),
            );
            break;
          case 'update_title':
            yield StreamTitleUpdate(
              (json['session_id'] ?? '').toString(),
              (json['data'] ?? '').toString(),
            );
            break;
          case 'break':
            yield StreamBreak(json['streaming'] == true);
            break;
          case 'error':
            yield StreamError((json['data'] ?? 'Error').toString());
            break;
        }

        // The web client also stops once the server flips streaming=false;
        // we let the stream complete naturally on EOF.
      }
    }
  }

  // Media ------------------------------------------------------------------

  Future<String> uploadImage({required String filePath, required String fileName}) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post<dynamic>(
        '/api/chat/post_image',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = res.data;
      return data is Map ? (data['filename'] ?? '').toString() : '';
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<Uint8List> getMediaBytes(String filename) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/chat/get_file',
        queryParameters: {'filename': filename},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final chatServiceProvider =
    Provider<ChatService>((ref) => ChatService(ref.watch(apiClientProvider)));

final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  ref.watch(apiClientProvider); // refresh on server-profile switch
  return ref.watch(chatServiceProvider).listSessions();
});
