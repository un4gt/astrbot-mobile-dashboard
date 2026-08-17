/// Full persona create/edit form -- close port of `PersonaForm.vue`.
///
/// Key behaviors mirrored from the web:
///   - `begin_dialogs` is a flat alternating list of user/assistant strings
///     (`[user, assistant, user, assistant, ...]`); the form pairs them
///     visually and validates each non-empty.
///   - `tools` semantics: `null` = use all tools (radio "All"); a list = a
///     custom subset (radio "Custom").
///   - MCP server chips are quick-select shortcuts that toggle every tool
///     belonging to that server in bulk.
///   - persona_id is locked when editing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../mcp/data/mcp_service.dart';
import '../data/persona_service.dart';

class PersonaFormScreen extends ConsumerStatefulWidget {
  const PersonaFormScreen({super.key, this.initial});
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<PersonaFormScreen> createState() => _PersonaFormScreenState();
}

class _PersonaFormScreenState extends ConsumerState<PersonaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  late final TextEditingController _promptCtrl;
  final _searchCtrl = TextEditingController();

  /// Mutable list of `[user, assistant, user, assistant, ...]`.
  late List<TextEditingController> _dialogCtrls;

  /// `null` -> use ALL tools (radio = all); `Set<String>` -> custom.
  Set<String>? _selectedTools;
  String _toolQuery = '';

  late final bool _isNew;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _isNew = p == null;
    _idCtrl = TextEditingController(text: (p?['persona_id'] ?? '').toString());
    _promptCtrl =
        TextEditingController(text: (p?['system_prompt'] ?? '').toString());

    final dialogs = p?['begin_dialogs'];
    final initialStrings = dialogs is List
        ? dialogs.map((e) => e?.toString() ?? '').toList()
        : <String>[];
    _dialogCtrls = [
      for (final s in initialStrings) TextEditingController(text: s),
    ];

    final tools = p?['tools'];
    if (tools == null) {
      _selectedTools = null;
    } else if (tools is List) {
      _selectedTools = tools.map((e) => e.toString()).toSet();
    } else {
      _selectedTools = <String>{};
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _promptCtrl.dispose();
    _searchCtrl.dispose();
    for (final c in _dialogCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _useAll => _selectedTools == null;

  void _setUseAll(bool value) {
    setState(() {
      if (value) {
        _selectedTools = null;
      } else {
        _selectedTools ??= <String>{};
      }
    });
  }

  void _toggleTool(String name, bool selected) {
    if (_selectedTools == null) return;
    setState(() {
      if (selected) {
        _selectedTools!.add(name);
      } else {
        _selectedTools!.remove(name);
      }
    });
  }

  bool _serverSelected(McpServer server, List<FunctionTool> tools) {
    if (_selectedTools == null) return true;
    final names =
        tools.where((t) => t.mcpServerName == server.name).map((t) => t.name);
    if (names.isEmpty) return false;
    return names.every(_selectedTools!.contains);
  }

  void _toggleServer(McpServer server, List<FunctionTool> tools) {
    if (_selectedTools == null) return;
    final names = tools
        .where((t) => t.mcpServerName == server.name)
        .map((t) => t.name)
        .toList();
    if (names.isEmpty) return;
    final allOn = names.every(_selectedTools!.contains);
    setState(() {
      if (allOn) {
        _selectedTools!.removeAll(names);
      } else {
        _selectedTools!.addAll(names);
      }
    });
  }

  void _addDialogPair() {
    setState(() {
      _dialogCtrls.add(TextEditingController());
      _dialogCtrls.add(TextEditingController());
    });
  }

  void _removeDialogAt(int index) {
    setState(() {
      _dialogCtrls.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate every dialog entry is non-empty (mirror PersonaForm.vue).
    for (var i = 0; i < _dialogCtrls.length; i++) {
      if (_dialogCtrls[i].text.trim().isEmpty) {
        final role = i.isEven ? 'user' : 'assistant';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Empty $role message at position ${i + 1}.')),
        );
        return;
      }
    }

    final body = <String, dynamic>{
      'persona_id': _idCtrl.text.trim(),
      'system_prompt': _promptCtrl.text,
      'begin_dialogs': _dialogCtrls.map((c) => c.text).toList(),
      'tools': _selectedTools?.toList(),
    };

    setState(() => _saving = true);
    try {
      await ref.read(personaServiceProvider).save(body, isNew: _isNew);
      ref.invalidate(personasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? 'Persona created.' : 'Persona saved.')),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(functionToolsProvider);
    final mcpServers = ref.watch(mcpServersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New persona' : 'Edit persona'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _idCtrl,
              enabled: _isNew,
              decoration: const InputDecoration(
                labelText: 'Persona ID',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: _promptCtrl,
              builder: (_, _) {
                final len = _promptCtrl.text.length;
                return TextFormField(
                  controller: _promptCtrl,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: 'System prompt',
                    alignLabelWithHint: true,
                    helperText: '$len character(s) · min 10',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'At least 10 characters'
                      : null,
                );
              },
            ),
            const SizedBox(height: 24),
            _toolsSection(tools, mcpServers),
            const SizedBox(height: 24),
            _dialogsSection(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tools

  Widget _toolsSection(
    AsyncValue<List<FunctionTool>> toolsAsync,
    AsyncValue<List<McpServer>> serversAsync,
  ) {
    final cs = Theme.of(context).colorScheme;
    return _Section(
      title: 'Tools',
      icon: Icons.build_outlined,
      trailing: _useAll
          ? const Chip(
              label: Text('All'),
              visualDensity: VisualDensity.compact,
            )
          : Chip(
              label: Text('${_selectedTools!.length} chosen'),
              visualDensity: VisualDensity.compact,
              backgroundColor: cs.primaryContainer,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<bool>(
            groupValue: _useAll,
            onChanged: (v) {
              if (v != null) _setUseAll(v);
            },
            child: const Column(
              children: [
                RadioListTile<bool>(
                  value: true,
                  title: Text('Use all function tools'),
                  subtitle: Text('Stored as `tools: null`'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<bool>(
                  value: false,
                  title: Text('Custom selection'),
                  subtitle: Text('Pick the subset of tools below'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (!_useAll) ...[
            const SizedBox(height: 8),
            toolsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Could not load tools: ${e is ApiException ? e.message : e}',
                style: TextStyle(color: cs.error),
              ),
              data: (tools) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MCP server quick-select chips.
                  serversAsync.maybeWhen(
                    data: (servers) {
                      if (servers.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MCP servers (quick-select)',
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final s in servers)
                                  FilterChip(
                                    label: Text(s.name),
                                    avatar: const Icon(Icons.dns_outlined,
                                        size: 16),
                                    selected: _serverSelected(s, tools),
                                    onSelected: (_) =>
                                        _toggleServer(s, tools),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search tools',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        setState(() => _toolQuery = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  _toolListView(tools),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolListView(List<FunctionTool> all) {
    final filtered = _toolQuery.isEmpty
        ? all
        : all.where((t) {
            return t.name.toLowerCase().contains(_toolQuery) ||
                (t.description?.toLowerCase().contains(_toolQuery) ?? false) ||
                (t.mcpServerName?.toLowerCase().contains(_toolQuery) ?? false);
          }).toList();
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No tools match.'),
      );
    }
    // Group by mcp_server_name (null = "Built-in").
    final groups = <String, List<FunctionTool>>{};
    for (final t in filtered) {
      final key = t.mcpServerName ?? 'Built-in';
      groups.putIfAbsent(key, () => []).add(t);
    }
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Built-in') return -1;
        if (b.key == 'Built-in') return 1;
        return a.key.compareTo(b.key);
      });

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final group in sortedGroups) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Text(
                group.key,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            for (final t in group.value)
              CheckboxListTile(
                value: _selectedTools?.contains(t.name) ?? false,
                onChanged: (v) => _toggleTool(t.name, v == true),
                dense: true,
                title: Text(t.name),
                subtitle: t.description != null && t.description!.isNotEmpty
                    ? Text(
                        t.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------- begin_dialogs

  Widget _dialogsSection() {
    return _Section(
      title: 'Preset dialog',
      icon: Icons.chat_outlined,
      trailing: Chip(
        label: Text('${_dialogCtrls.length ~/ 2} pair(s)'),
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        children: [
          if (_dialogCtrls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Pre-fill conversation turns the bot will treat as already-said.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          for (var i = 0; i < _dialogCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextFormField(
                controller: _dialogCtrls[i],
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: i.isEven ? 'User #${(i ~/ 2) + 1}' : 'Assistant #${(i ~/ 2) + 1}',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    i.isEven ? Icons.person_outline : Icons.smart_toy_outlined,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove',
                    onPressed: () => _removeDialogAt(i),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addDialogPair,
            icon: const Icon(Icons.add),
            label: const Text('Add user/assistant pair'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
