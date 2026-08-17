/// Conversation detail viewer. Shows the message history as bubble cards
/// (user/assistant/system roles). Title editable inline; messages are
/// read-only on mobile (the web's JSON-edit mode is omitted -- power users
/// can still edit via the dashboard).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/conversation_service.dart';

class ConversationDetailScreen extends ConsumerStatefulWidget {
  const ConversationDetailScreen({super.key, required this.summary});
  final Map<String, dynamic> summary;

  @override
  ConsumerState<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState
    extends ConsumerState<ConversationDetailScreen> {
  late ConversationSummary _summary = ConversationSummary(widget.summary);
  Future<ConversationDetail>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(conversationServiceProvider).detail(
          userId: _summary.userId,
          cid: _summary.cid,
        );
  }

  Future<void> _editTitle() async {
    final ctrl = TextEditingController(text: _summary.title);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == _summary.title) return;
    try {
      await ref.read(conversationServiceProvider).updateTitle(
            userId: _summary.userId,
            cid: _summary.cid,
            title: result,
          );
      setState(() {
        final next = Map<String, dynamic>.from(_summary.raw)..['title'] = result;
        _summary = ConversationSummary(next);
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete conversation?',
      message: '"${_summary.title}" will be removed.',
      destructive: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref
          .read(conversationServiceProvider)
          .deleteOne(userId: _summary.userId, cid: _summary.cid);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _summary.parseSession();
    return Scaffold(
      appBar: AppBar(
        title: Text(_summary.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit title',
            onPressed: _editTitle,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(Icons.smart_toy_outlined, size: 14),
                  label: Text(session.platform),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(session.messageType),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.tag, size: 14),
                  label: Text(session.sessionId),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<ConversationDetail>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final e = snap.error;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        e is ApiException ? e.message : e.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final history = snap.data?.history ?? const [];
                if (history.isEmpty) {
                  return const Center(child: Text('No messages.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: history.length,
                  itemBuilder: (_, i) => _MessageBubble(message: history[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Map<String, dynamic> message;

  String get _role => (message['role'] ?? 'user').toString();
  String get _content {
    final c = message['content'];
    if (c is String) return c;
    if (c is List) {
      // Multi-modal payloads: extract text segments only.
      return c
          .whereType<Map>()
          .map((m) => m['text'] ?? m['content'] ?? '')
          .where((s) => s.toString().isNotEmpty)
          .join('\n');
    }
    return c?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = _role == 'user';
    final isSystem = _role == 'system';
    final color = isSystem
        ? cs.tertiaryContainer
        : (isUser ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
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
                children: [
                  Text(
                    _role,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(_content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
