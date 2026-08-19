/// Bottom-sheet editor for `type: "dict"` fields -- a `Map<String, String>`.
/// Mirrors `ObjectEditor.vue` from the dashboard.
library;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';

class DictConfigField extends StatefulWidget {
  const DictConfigField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String? label;

  @override
  State<DictConfigField> createState() => _DictConfigFieldState();
}

class _DictConfigFieldState extends State<DictConfigField> {
  late Map<String, dynamic> _value = Map<String, dynamic>.from(widget.value);

  Future<void> _open() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _DictEditorSheet(
          initial: _value,
          label: widget.label ?? 'Key-value pairs',
          onSave: (next) {
            setState(() => _value = next);
            widget.onChanged(Map<String, dynamic>.from(_value));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _value.isEmpty
        ? '(empty)'
        : _value.entries.take(2).map((e) => '${e.key}=${e.value}').join(', ') +
            (_value.length > 2 ? ' ... +${_value.length - 2}' : '');
    return OutlinedButton.icon(
      onPressed: _open,
      icon: const Icon(Icons.dataset_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${_value.length} pair(s)  $preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DictEditorSheet extends StatefulWidget {
  const _DictEditorSheet({
    required this.initial,
    required this.label,
    required this.onSave,
  });

  final Map<String, dynamic> initial;
  final String label;
  final void Function(Map<String, dynamic>) onSave;

  @override
  State<_DictEditorSheet> createState() => _DictEditorSheetState();
}

class _Row {
  final TextEditingController k;
  final TextEditingController v;
  _Row(String key, String value)
      : k = TextEditingController(text: key),
        v = TextEditingController(text: value);
  void dispose() {
    k.dispose();
    v.dispose();
  }
}

class _DictEditorSheetState extends State<_DictEditorSheet> {
  late final List<_Row> _rows = widget.initial.entries
      .map((e) => _Row(e.key, e.value?.toString() ?? ''))
      .toList();

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _add() => setState(() => _rows.add(_Row('', '')));
  void _remove(int i) {
    _rows.removeAt(i).dispose();
    setState(() {});
  }

  void _save() {
    final out = <String, dynamic>{};
    for (final r in _rows) {
      final k = r.k.text.trim();
      if (k.isEmpty) continue;
      out[k] = r.v.text;
    }
    widget.onSave(out);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
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
                  itemCount: _rows.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _rows[i].k,
                            decoration: const InputDecoration(
                              hintText: 'key',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _rows[i].v,
                            decoration: const InputDecoration(
                              hintText: 'value',
                              isDense: true,
                              border: OutlineInputBorder(),
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
                      child: Text(context.trM('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(context.trM('common.save')),
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
