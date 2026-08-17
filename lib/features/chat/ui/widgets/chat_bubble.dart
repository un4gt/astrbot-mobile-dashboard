/// Chat message bubble. User messages right-aligned, assistant left.
library;

import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import 'chat_media_image.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});
  final ChatMessage message;

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = message.error
        ? cs.errorContainer
        : (_isUser ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest);

    final children = <Widget>[];
    if (message.reasoning.isNotEmpty) {
      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.reasoning,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
        ),
      ));
      children.add(const SizedBox(height: 6));
    }
    if (message.content.isNotEmpty) {
      children.add(SelectableText(message.content));
    }
    for (final filename in message.images) {
      children.add(const SizedBox(height: 6));
      children.add(ChatMediaImage(filename: filename));
    }
    if (message.audio != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.graphic_eq, size: 16),
            SizedBox(width: 4),
            Text('audio'),
          ],
        ),
      ));
    }
    if (message.streaming && children.isEmpty) {
      children.add(const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    } else if (message.streaming) {
      children.add(const SizedBox(height: 4));
      children.add(const _BlinkingCursor());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(Icons.smart_toy_outlined, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
          if (_isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
