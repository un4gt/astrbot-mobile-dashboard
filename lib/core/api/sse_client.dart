/// Dio-based SSE consumer.
///
/// AstrBot's `/api/live-log` is not standard EventSource -- it is a streamed
/// HTTP response whose chunks contain `data: {...}\n\n` events. We mirror
/// the Vue dashboard's fetch+ReadableStream approach using dio's
/// `ResponseType.stream` (see `dashboard/src/stores/common.js` lines 43-126).
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class SseClient {
  SseClient(this._dio);
  final Dio _dio;

  /// Connects to [path] and yields decoded JSON payloads from each event.
  /// Caller is expected to handle reconnection -- [connect] returns a single
  /// stream that completes on EOF / error.
  Stream<Map<String, dynamic>> connect(String path,
      {Map<String, String>? extraHeaders}) async* {
    final resp = await _dio.get<ResponseBody>(
      path,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          ...?extraHeaders,
        },
        // No idle timeout -- live logs may be quiet for long stretches.
        receiveTimeout: Duration.zero,
      ),
    );
    final stream = resp.data?.stream;
    if (stream == null) return;

    var buffer = '';
    var carryover = '';
    await for (final bytes in stream) {
      buffer += utf8.decode(bytes, allowMalformed: true);
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final event = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);
        for (final line in event.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          // Reassemble JSON that span multiple events when needed.
          carryover += payload;
          try {
            final decoded = jsonDecode(carryover);
            carryover = '';
            if (decoded is Map<String, dynamic>) yield decoded;
          } catch (_) {
            // wait for more bytes
          }
        }
      }
    }
  }
}
