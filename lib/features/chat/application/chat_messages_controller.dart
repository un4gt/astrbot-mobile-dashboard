/// Per-session controller. Holds the message list, drives the streaming
/// `sendMessage` call, and emits title updates back to the session list.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/chat_service.dart';
import '../domain/chat_message.dart';

class ChatMessagesState {
  final List<ChatMessage> messages;
  final bool sending;
  final String? error;
  const ChatMessagesState({
    this.messages = const [],
    this.sending = false,
    this.error,
  });

  ChatMessagesState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ChatMessagesState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatMessagesController
    extends FamilyNotifier<ChatMessagesState, String> {
  StreamSubscription<ChatStreamEvent>? _sub;

  /// Set when a history fetch was discarded because a send was streaming;
  /// the list is re-fetched once the send settles so nothing is lost.
  bool _hydrateSuppressed = false;

  @override
  ChatMessagesState build(String sessionId) {
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(() => _hydrate(sessionId));
    return const ChatMessagesState();
  }

  Future<void> _hydrate(String sessionId) async {
    try {
      final history =
          await ref.read(chatServiceProvider).getSessionMessages(sessionId);
      // A send that started while this fetch was in flight owns the message
      // list -- applying (possibly empty) stale history on top would wipe the
      // streaming reply. This is exactly the first-send-in-a-new-session
      // flow, where both kick off at the same time.
      if (state.sending) {
        _hydrateSuppressed = true;
        return;
      }
      state = state.copyWith(
        messages: history
            .map((m) => ChatMessage.fromServer(m))
            .where((m) => m.content.isNotEmpty || m.images.isNotEmpty)
            .toList(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Replace the last message (the streaming placeholder) with [update].
  void _updateLast(ChatMessage Function(ChatMessage last) update) {
    if (state.messages.isEmpty) return;
    final next = update(state.messages.last);
    state = state.copyWith(
      messages: [...state.messages.sublist(0, state.messages.length - 1), next],
    );
  }

  Future<void> reload() async {
    state = const ChatMessagesState();
    await _hydrate(arg);
  }

  Future<void> send({
    required String text,
    List<String> imageNames = const [],
    String? audioName,
    String? selectedProvider,
    String? selectedModel,
    bool enableStreaming = true,
  }) async {
    if (text.isEmpty && imageNames.isEmpty && audioName == null) return;
    final user = ChatMessage(
      role: 'user',
      content: text,
      images: imageNames,
      audio: audioName,
    );
    final placeholder = const ChatMessage(role: 'assistant', content: '', streaming: true);
    state = state.copyWith(
      messages: [...state.messages, user, placeholder],
      sending: true,
      clearError: true,
    );

    final sessionId = arg;
    try {
      final stream = ref.read(chatServiceProvider).sendMessage(
            sessionId: sessionId,
            text: text,
            imageNames: imageNames,
            audioName: audioName,
            selectedProvider: selectedProvider,
            selectedModel: selectedModel,
            enableStreaming: enableStreaming,
          );
      var sawPlain = false;
      await for (final ev in stream) {
        switch (ev) {
          case StreamPlainChunk(:final text, :final reasoning, :final streaming):
            sawPlain = true;
            _updateLast((last) => last.copyWith(
                  content: reasoning ? last.content : last.content + text,
                  reasoning:
                      reasoning ? last.reasoning + text : last.reasoning,
                  streaming: streaming,
                ));
            break;
          case StreamMedia(:final kind, :final filename):
            if (kind == 'image') {
              _updateLast(
                  (last) => last.copyWith(images: [...last.images, filename]));
            } else if (kind == 'record') {
              _updateLast((last) => last.copyWith(audio: filename));
            }
            break;
          case StreamTitleUpdate():
            // Refresh the session list so the new title shows up.
            ref.invalidate(chatSessionsProvider);
            break;
          case StreamBreak():
            // ignore in mobile UI -- we render continuously
            break;
          case StreamError(:final message):
            _updateLast((last) =>
                last.copyWith(content: message, error: true, streaming: false));
            state = state.copyWith(error: message);
            break;
        }
      }
      if (!sawPlain) {
        // No plain chunks received -> remove empty placeholder
        if (state.messages.isNotEmpty &&
            state.messages.last.streaming &&
            state.messages.last.content.isEmpty &&
            state.messages.last.images.isEmpty) {
          state = state.copyWith(
            messages: state.messages.sublist(0, state.messages.length - 1),
          );
        }
      }
    } on ApiException catch (e) {
      // Swap placeholder for an error bubble.
      if (state.messages.isNotEmpty && state.messages.last.streaming) {
        _updateLast((last) => last.copyWith(
              content: e.message,
              streaming: false,
              error: true,
            ));
      } else {
        state = state.copyWith(error: e.message);
      }
    } finally {
      // Mark assistant message as no longer streaming (in case server omitted
      // the final break).
      if (state.messages.isNotEmpty && state.messages.last.streaming) {
        _updateLast((last) => last.copyWith(streaming: false));
      }
      state = state.copyWith(sending: false);
      // If a history fetch was suppressed during this send, run it now that
      // the stream has settled -- the server has the full transcript and the
      // reply is persisted there.
      if (_hydrateSuppressed) {
        _hydrateSuppressed = false;
        await _hydrate(arg);
      }
    }
  }
}

final chatMessagesProvider = NotifierProvider.family<
    ChatMessagesController, ChatMessagesState, String>(
  ChatMessagesController.new,
);
