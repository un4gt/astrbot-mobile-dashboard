/// Conversation list with platform / message-type / keyword filters,
/// long-press multi-select for batch delete, and pull-to-refresh.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/conversation_service.dart';

const _messageTypes = ['GroupMessage', 'FriendMessage', 'OfficialDocument'];

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final Set<String> _selectedPlatforms = {};
  final Set<String> _selectedTypes = {};
  String _searchQuery = '';

  int _page = 1;
  static const _pageSize = 20;

  bool _loading = false;
  String? _error;
  int _totalPages = 1;
  final List<ConversationSummary> _items = [];

  // Multi-select mode for batch delete.
  final Set<String> _selectedKeys = {};
  bool get _selecting => _selectedKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _keyOf(ConversationSummary c) => '${c.userId}::${c.cid}';

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loading &&
        _page < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _items.clear();
      _selectedKeys.clear();
      _error = null;
    });
    await _fetch();
  }

  Future<void> _loadMore() async {
    if (_page >= _totalPages) return;
    _page += 1;
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(conversationServiceProvider).list(
            page: _page,
            pageSize: _pageSize,
            platforms: _selectedPlatforms.toList(),
            messageTypes: _selectedTypes.toList(),
            search: _searchQuery.trim(),
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _totalPages = res.totalPages;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSingle(ConversationSummary c) async {
    final ok = await showConfirmDialog(
      context: context,
      title: context.trM('conversation.deleteTitle'),
      message: 'Conversation "${c.title}" will be removed permanently.',
      destructive: true,
      confirmLabel: context.trM('common.delete'),
    );
    if (!ok) return;
    try {
      await ref
          .read(conversationServiceProvider)
          .deleteOne(userId: c.userId, cid: c.cid);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete ${_selectedKeys.length} conversations?',
      message: context.trM('conversation.deleteSelectedMessage'),
      destructive: true,
      confirmLabel: context.trM('common.delete'),
    );
    if (!ok) return;
    final batch = _items
        .where((c) => _selectedKeys.contains(_keyOf(c)))
        .map((c) => (userId: c.userId, cid: c.cid))
        .toList();
    try {
      final result =
          await ref.read(conversationServiceProvider).deleteBatch(batch);
      _snack('Deleted ${result.deleted}, failed ${result.failed}.');
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _editTitle(ConversationSummary c) async {
    final ctrl = TextEditingController(text: c.title);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.trM('conversation.editTitle')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(context.trM('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.trM('common.save')),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == c.title) return;
    try {
      await ref.read(conversationServiceProvider).updateTitle(
            userId: c.userId,
            cid: c.cid,
            title: result,
          );
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selectedKeys.clear),
              )
            : null,
        title: Text(_selecting
            ? '${_selectedKeys.length} selected'
            : 'Conversations'),
        actions: _selecting
            ? [
                IconButton(
                  tooltip: context.trM('conversation.deleteSelected'),
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline),
                ),
              ]
            : [
                IconButton(
                  tooltip: context.trM('common.refresh'),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
      ),
      body: Column(
        children: [
          _filtersBar(),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _items.length + (_loading || _page < _totalPages ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : (_page < _totalPages
                                ? OutlinedButton(
                                    onPressed: _loadMore,
                                    child: Text(context.trM('common.loadMore')),
                                  )
                                : const SizedBox.shrink()),
                      ),
                    );
                  }
                  final c = _items[i];
                  final key = _keyOf(c);
                  final selected = _selectedKeys.contains(key);
                  final session = c.parseSession();
                  return ListTile(
                    selected: selected,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    leading: _selecting
                        ? Checkbox(
                            value: selected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedKeys.add(key);
                              } else {
                                _selectedKeys.remove(key);
                              }
                            }),
                          )
                        : CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            child: Icon(
                              session.messageType == 'GroupMessage'
                                  ? Icons.groups_outlined
                                  : Icons.person_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                    title: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        session.platform,
                        session.messageType,
                        session.sessionId,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      if (_selecting) {
                        setState(() {
                          if (selected) {
                            _selectedKeys.remove(key);
                          } else {
                            _selectedKeys.add(key);
                          }
                        });
                      } else {
                        context.push('/more/conversation/detail', extra: c.raw);
                      }
                    },
                    onLongPress: () => setState(() => _selectedKeys.add(key)),
                    trailing: _selecting
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  _editTitle(c);
                                  break;
                                case 'delete':
                                  _deleteSingle(c);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: Text(context.trM('conversation.editTitle')),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline,
                                      color: Theme.of(context).colorScheme.error),
                                  title: Text(context.trM('common.delete'),
                                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtersBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.trM('conversation.searchHint'),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              _searchQuery = v.trim();
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in _messageTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(t),
                      selected: _selectedTypes.contains(t),
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _selectedTypes.add(t);
                          } else {
                            _selectedTypes.remove(t);
                          }
                        });
                        _refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
