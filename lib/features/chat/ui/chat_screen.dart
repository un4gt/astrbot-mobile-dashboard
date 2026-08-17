/// Multi-session chat screen.
///
/// Layout: Drawer (sessions list) + main pane (messages + input).
/// Streaming reply uses [ChatMessagesController]. Image attachment uses
/// `file_picker`; voice button is a placeholder per the agreed scope.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../application/chat_messages_controller.dart';
import '../data/chat_service.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_media_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _currentSessionId;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();

  // Per-message staged attachments (uploaded server filenames + their bytes
  // for local preview).
  final List<({String filename, String localPath})> _stagedImages = [];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<String?> _ensureSession(WidgetRef ref) async {
    if (_currentSessionId != null) return _currentSessionId;
    try {
      final id = await ref.read(chatServiceProvider).createSession();
      ref.invalidate(chatSessionsProvider);
      setState(() => _currentSessionId = id);
      return id;
    } on ApiException catch (e) {
      _snack(e.message, error: true);
      return null;
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _selectSession(String id) async {
    setState(() => _currentSessionId = id);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _newSession() async {
    setState(() => _currentSessionId = null);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _renameSession(ChatSession s) async {
    final ctrl = TextEditingController(text: s.title);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename session'),
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
    if (result == null || result.isEmpty) return;
    try {
      await ref.read(chatServiceProvider).renameSession(s.id, result);
      ref.invalidate(chatSessionsProvider);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _deleteSession(ChatSession s) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete session?',
      message: '"${s.title}" and all its messages will be removed.',
      destructive: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(chatServiceProvider).deleteSession(s.id);
      ref.invalidate(chatSessionsProvider);
      if (_currentSessionId == s.id) {
        setState(() => _currentSessionId = null);
      }
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _attachImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    final path = picked?.files.single.path;
    final name = picked?.files.single.name;
    if (path == null || name == null) return;
    try {
      final filename = await ref
          .read(chatServiceProvider)
          .uploadImage(filePath: path, fileName: name);
      if (filename.isEmpty) {
        _snack('Upload returned empty filename.', error: true);
        return;
      }
      setState(() {
        _stagedImages.add((filename: filename, localPath: path));
      });
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _stagedImages.isEmpty) return;
    final sessionId = await _ensureSession(ref);
    if (sessionId == null) return;
    final imageFilenames = _stagedImages.map((e) => e.filename).toList();
    _inputCtrl.clear();
    setState(() => _stagedImages.clear());

    await ref.read(chatMessagesProvider(sessionId).notifier).send(
          text: text,
          imageNames: imageFilenames,
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(chatSessionsProvider);
    final currentId = _currentSessionId;

    // Auto-scroll only when the message count changes (avoids triggering on
    // every keystroke during streaming, which previously starved the IME and
    // made the chat input feel unresponsive).
    if (currentId != null) {
      ref.listen<ChatMessagesState>(chatMessagesProvider(currentId),
          (prev, next) {
        if (prev == null || next.messages.length != prev.messages.length) {
          _scrollToBottom();
        }
      });
    }

    final messages = currentId == null
        ? null
        : ref.watch(chatMessagesProvider(currentId));
    final sending = messages?.sending ?? false;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_currentTitle(context, sessions)),
      ),
      drawer: _buildDrawer(sessions),
      body: Column(
        children: [
          if (currentId == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.trM('chat.startHint'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: messages == null || messages.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: messages?.error != null
                            ? Text(messages!.error!)
                            : Text(context.trM('chat.noMessages')),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: messages.messages.length,
                      itemBuilder: (_, i) =>
                          ChatBubble(message: messages.messages[i]),
                    ),
            ),
          if (_stagedImages.isNotEmpty)
            _stagedRow(),
          _inputBar(sending),
        ],
      ),
    );
  }

  String _currentTitle(BuildContext context, AsyncValue<List<ChatSession>> sessions) {
    final id = _currentSessionId;
    if (id == null) return context.trM('chat.title');
    final list = sessions.valueOrNull ?? const [];
    final s = list.firstWhere(
      (x) => x.id == id,
      orElse: () => ChatSession({'session_id': id}),
    );
    return s.title;
  }

  Widget _buildDrawer(AsyncValue<List<ChatSession>> sessions) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(context.trM('chat.sessions'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: context.trM('common.refresh'),
                    onPressed: () => ref.invalidate(chatSessionsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.trM('chat.newSession')),
              onTap: _newSession,
            ),
            const Divider(height: 1),
            Expanded(
              child: sessions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(e is ApiException ? e.message : e.toString()),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(child: Text(context.trM('chat.noSessions')));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      final selected = s.id == _currentSessionId;
                      return ListTile(
                        selected: selected,
                        leading: const Icon(Icons.chat_outlined),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11),
                        ),
                        onTap: () => _selectSession(s.id),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            switch (action) {
                              case 'rename':
                                _renameSession(s);
                                break;
                              case 'delete':
                                _deleteSession(s);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: ListTile(
                                leading: const Icon(Icons.edit_outlined),
                                title: Text(context.trM('chat.rename')),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error),
                                title: Text(context.trM('chat.delete'),
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.error)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stagedRow() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _stagedImages.length,
        itemBuilder: (_, i) {
          final s = _stagedImages[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ChatMediaImage(filename: s.filename, maxWidth: 64),
                  ),
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: IconButton.filledTonal(
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                    onPressed: () =>
                        setState(() => _stagedImages.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _inputBar(bool sending) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: context.trM('chat.attachImage'),
              onPressed: sending ? null : _attachImage,
              icon: const Icon(Icons.image_outlined),
            ),
            IconButton(
              tooltip: context.trM('chat.voiceTooltip'),
              onPressed: () => _snack(context.trM('chat.voiceComingSoon')),
              icon: const Icon(Icons.mic_none_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: context.trM('chat.send'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: sending ? null : _send,
              style: FilledButton.styleFrom(
                minimumSize: const Size(56, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
