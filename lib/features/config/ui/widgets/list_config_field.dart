/// Bottom-sheet editor for `type: "list"` fields. Holds a `List<dynamic>` of
/// scalar values (strings, ints, etc.). Phase 2 only supports lists of
/// strings -- list-of-objects (used by some platform/provider templates)
/// falls back to a JSON multiline TextField.
library;

import 'dart:convert';
import 'package:flutter/material.dart';

class ListConfigField extends StatefulWidget {
  const ListConfigField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final List<dynamic> value;
  final ValueChanged<List<dynamic>> onChanged;
  final String? label;

  @override
  State<ListConfigField> createState() => _ListConfigFieldState();
}

class _ListConfigFieldState extends State<ListConfigField> {
  late List<dynamic> _items = List<dynamic>.from(widget.value);

  bool get _isStringList =>
      _items.every((e) => e is String || e is num || e is bool || e == null);

  void _emit() => widget.onChanged(List<dynamic>.from(_items));

  Future<void> _open() async {
    if (!_isStringList) {
      // Complex list (e.g. list of objects). Fall back to JSON editor.
      await _openJsonEditor();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: _ListEditorSheet(
            initial: _items.map((e) => e?.toString() ?? '').toList(),
            label: widget.label ?? 'List items',
            onSave: (next) {
              setState(() => _items = next);
              _emit();
            },
          ),
        );
      },
    );
  }

  Future<void> _openJsonEditor() async {
    final ctrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(_items),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit list (JSON)'),
        content: SingleChildScrollView(
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    try {
      final parsed = jsonDecode(result);
      if (parsed is List) {
        setState(() => _items = parsed);
        _emit();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid JSON, no changes saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = _items.isEmpty
        ? '(empty)'
        : _items.take(3).map((e) => e.toString()).join(', ') +
            (_items.length > 3 ? ' ... +${_items.length - 3}' : '');
    return OutlinedButton.icon(
      onPressed: _open,
      icon: const Icon(Icons.edit_note),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${_items.length} item(s)  $preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurface),
        ),
      ),
    );
  }
}

class _ListEditorSheet extends StatefulWidget {
  const _ListEditorSheet({
    required this.initial,
    required this.label,
    required this.onSave,
  });
  final List<String> initial;
  final String label;
  final void Function(List<dynamic>) onSave;

  @override
  State<_ListEditorSheet> createState() => _ListEditorSheetState();
}

class _ListEditorSheetState extends State<_ListEditorSheet> {
  late final List<TextEditingController> _ctrls =
      widget.initial.map((s) => TextEditingController(text: s)).toList();

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() => setState(() => _ctrls.add(TextEditingController()));
  void _remove(int i) {
    final removed = _ctrls.removeAt(i);
    removed.dispose();
    setState(() {});
  }

  void _save() {
    final out = _ctrls.map((c) => c.text).where((s) => s.isNotEmpty).toList();
    widget.onSave(out);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.label,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton.filledTonal(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _ctrls.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrls[i],
                            decoration: InputDecoration(
                              hintText: 'Item ${i + 1}',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _remove(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
