/// Live log stream + history fetch for the Console screen.
///
/// Mirrors `useCommonStore.createEventSource` in
/// `dashboard/src/stores/common.js`:
///   1. GET /api/log-history -> array of log entries
///   2. open SSE on /api/live-log, append entries as they arrive
///   3. ring buffer capped at [maxEntries]
///   4. auto-reconnect with exponential backoff
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/sse_client.dart';

class LogEntry {
  final String level; // INFO, DEBUG, WARNING, ERROR, CRITICAL, ...
  final String data; // raw log line (may contain ANSI codes)
  LogEntry({required this.level, required this.data});

  factory LogEntry.fromMap(Map raw) {
    return LogEntry(
      level: (raw['level'] ?? 'INFO').toString(),
      data: (raw['data'] ?? '').toString(),
    );
  }
}

class LogStreamState {
  final List<LogEntry> entries;
  final bool connected;
  final String? error;
  const LogStreamState({
    required this.entries,
    required this.connected,
    this.error,
  });

  LogStreamState copyWith({
    List<LogEntry>? entries,
    bool? connected,
    String? error,
    bool clearError = false,
  }) =>
      LogStreamState(
        entries: entries ?? this.entries,
        connected: connected ?? this.connected,
        error: clearError ? null : (error ?? this.error),
      );
}

class LogStreamController extends Notifier<LogStreamState> {
  static const int maxEntries = 1000;
  static const _backoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  StreamSubscription<Map<String, dynamic>>? _sub;
  int _retry = 0;
  bool _stopped = false;

  @override
  LogStreamState build() {
    ref.onDispose(_stop);
    // Kick off connection on first watch.
    Future.microtask(_start);
    return const LogStreamState(entries: [], connected: false);
  }

  Future<void> _start() async {
    if (_stopped) return;
    final dio = ref.read(apiClientProvider);
    // 1. History pre-fill
    try {
      final hist = await dio.get<dynamic>('/api/log-history');
      final data = hist.data;
      if (data is Map && data['logs'] is List) {
        final list = (data['logs'] as List)
            .whereType<Map>()
            .map(LogEntry.fromMap)
            .toList();
        state = state.copyWith(entries: _capped(list));
      }
    } on DioException {
      // History is optional; proceed to live stream regardless.
    }

    // 2. Live stream
    try {
      final stream = SseClient(dio).connect('/api/live-log');
      _sub = stream.listen(
        _onEvent,
        onError: (e, _) => _onClosed(error: e?.toString()),
        onDone: () => _onClosed(),
        cancelOnError: true,
      );
      state = state.copyWith(connected: true, clearError: true);
      _retry = 0;
    } catch (e) {
      _onClosed(error: e.toString());
    }
  }

  void _onEvent(Map<String, dynamic> ev) {
    if (ev['type'] != 'log') return;
    final next = [...state.entries, LogEntry.fromMap(ev)];
    state = state.copyWith(entries: _capped(next));
  }

  void _onClosed({String? error}) {
    if (_stopped) return;
    state = state.copyWith(connected: false, error: error);
    _sub = null;
    final delay = _backoff[_retry.clamp(0, _backoff.length - 1)];
    _retry += 1;
    Future.delayed(delay, () {
      if (_stopped) return;
      _start();
    });
  }

  List<LogEntry> _capped(List<LogEntry> list) {
    if (list.length <= maxEntries) return list;
    return list.sublist(list.length - maxEntries);
  }

  void clear() {
    state = state.copyWith(entries: const []);
  }

  /// Manual reconnect (e.g. user tapped retry).
  void reconnect() {
    _sub?.cancel();
    _sub = null;
    _retry = 0;
    _start();
  }

  void _stop() {
    _stopped = true;
    _sub?.cancel();
    _sub = null;
  }
}

final logStreamProvider =
    NotifierProvider<LogStreamController, LogStreamState>(
        LogStreamController.new);
