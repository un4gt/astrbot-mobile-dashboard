/// In-memory message model used by the chat UI. Server-stored messages have
/// the OpenAI-style `{role, content}` shape; we widen with optional
/// embedded media filenames and a "streaming" flag for the reply currently
/// being received.
library;

class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final String reasoning;
  final List<String> images; // server filenames (resolved via /api/chat/get_file)
  final String? audio;
  final bool streaming;
  final bool error;

  const ChatMessage({
    required this.role,
    required this.content,
    this.reasoning = '',
    this.images = const [],
    this.audio,
    this.streaming = false,
    this.error = false,
  });

  ChatMessage copyWith({
    String? role,
    String? content,
    String? reasoning,
    List<String>? images,
    String? audio,
    bool? streaming,
    bool? error,
  }) =>
      ChatMessage(
        role: role ?? this.role,
        content: content ?? this.content,
        reasoning: reasoning ?? this.reasoning,
        images: images ?? this.images,
        audio: audio ?? this.audio,
        streaming: streaming ?? this.streaming,
        error: error ?? this.error,
      );

  /// Adapt a server-side history row (from `/api/chat/get_session`) into our
  /// local model. Each row is a `PlatformMessageHistory` dump whose payload
  /// lives in a nested `content` dict:
  /// `{platform_id, sender_id, content: {type: 'user'|'bot', message,
  ///   reasoning?, image_url?: [filenames]}, ...}`
  /// Older/simple shapes (`{role, content}` at the top level) are still
  /// accepted as a fallback.
  factory ChatMessage.fromServer(Map<String, dynamic> raw) {
    // Unwrap one nesting level when the payload is in `content`.
    if (raw['content'] is Map && raw['content']['type'] != null) {
      final inner = Map<String, dynamic>.from(raw['content'] as Map);
      if (raw['sender_id'] != null) {
        inner['sender_id'] = raw['sender_id'];
      }
      raw = inner;
    }

    final role = (raw['role'] ?? raw['type'] ?? 'user').toString();
    final c = raw['message'] ?? raw['content'] ?? '';
    String text;
    final images = <String>[];
    if (c is String) {
      text = c;
    } else if (c is List) {
      final buf = StringBuffer();
      for (final seg in c.whereType<Map>()) {
        final type = seg['type']?.toString();
        if (type == 'text') {
          buf.writeln((seg['text'] ?? '').toString());
        } else if (type == 'image') {
          final url = seg['image_url']?['url']?.toString() ??
              seg['filename']?.toString();
          if (url != null) images.add(url);
        }
      }
      text = buf.toString().trim();
    } else {
      text = c.toString();
    }

    // webchat rows carry image/audio filenames as sibling fields of the text.
    for (final img in (raw['image_url'] as List? ?? const [])) {
      final name = img?.toString();
      if (name != null && name.isNotEmpty) images.add(name);
    }

    return ChatMessage(
      role: role == 'bot' ? 'assistant' : role,
      content: text,
      reasoning: (raw['reasoning'] ?? '').toString(),
      images: images,
      audio: raw['audio_url'] is List && (raw['audio_url'] as List).isNotEmpty
          ? ((raw['audio_url'] as List).first)?.toString()
          : null,
    );
  }
}
