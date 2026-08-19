/// Shared bottom-sheet picker widgets used by every `_special` selector.
///
/// All `_special` pickers follow the same UX: a tonal "Change"/"Edit" button
/// next to a preview of the current value -> tap opens a modal bottom sheet
/// with a search box and a scrollable list -> Confirm to commit.
library;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';

class PickerEntry {
  final String id;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  const PickerEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.emoji,
  });
}

/// Modal bottom sheet that lets the user pick a single id from [entries].
/// Returns the chosen id (empty string when "Clear selection" tapped) or
/// `null` on cancel. [currentValue] highlights the active row.
Future<String?> showSinglePickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerEntry> entries,
  required String? currentValue,
  bool allowClear = true,
  String clearLabel = 'Clear selection',
  String emptyHint = 'Nothing to choose from.',
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _PickerSheet(
      title: title,
      entries: entries,
      multi: false,
      initialSingle: currentValue ?? '',
      allowClear: allowClear,
      clearLabel: clearLabel,
      emptyHint: emptyHint,
    ),
  );
}

/// Multi-select variant. Returns the new list (possibly empty) on confirm or
/// `null` on cancel.
Future<List<String>?> showMultiPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerEntry> entries,
  required List<String> currentValues,
  String emptyHint = 'Nothing to choose from.',
}) {
  return showModalBottomSheet<List<String>?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _PickerSheet(
      title: title,
      entries: entries,
      multi: true,
      initialMulti: List<String>.from(currentValues),
      emptyHint: emptyHint,
    ),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.entries,
    required this.multi,
    this.initialSingle = '',
    this.initialMulti = const [],
    this.allowClear = true,
    this.clearLabel = 'Clear selection',
    this.emptyHint = 'Nothing to choose from.',
  });

  final String title;
  final List<PickerEntry> entries;
  final bool multi;
  final String initialSingle;
  final List<String> initialMulti;
  final bool allowClear;
  final String clearLabel;
  final String emptyHint;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late String _single = widget.initialSingle;
  late final Set<String> _multi = {...widget.initialMulti};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PickerEntry> get _filtered {
    if (_query.isEmpty) return widget.entries;
    final q = _query.toLowerCase();
    return widget.entries.where((e) {
      return e.id.toLowerCase().contains(q) ||
          e.title.toLowerCase().contains(q) ||
          (e.subtitle?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: Column(
          children: [
            // Drag handle + title.
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (widget.multi)
                    Text(
                      '${_multi.length} selected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.trM('common.search'),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      itemCount: filtered.length +
                          (widget.allowClear && !widget.multi ? 1 : 0),
                      itemBuilder: (_, idx) {
                        if (widget.allowClear && !widget.multi && idx == 0) {
                          return _row(
                            const PickerEntry(id: '', title: ''),
                            isClear: true,
                          );
                        }
                        final entryIdx =
                            (widget.allowClear && !widget.multi) ? idx - 1 : idx;
                        return _row(filtered[entryIdx]);
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.trM('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (widget.multi) {
                          Navigator.pop(context, _multi.toList());
                        } else {
                          Navigator.pop(context, _single);
                        }
                      },
                      child: Text(context.trM('common.confirm')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(widget.emptyHint,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _row(PickerEntry e, {bool isClear = false}) {
    final cs = Theme.of(context).colorScheme;
    final selected = isClear
        ? (!widget.multi && _single.isEmpty)
        : (widget.multi ? _multi.contains(e.id) : _single == e.id);

    Widget leading;
    if (isClear) {
      leading = Icon(Icons.cancel_outlined, color: cs.outline);
    } else if (e.emoji != null) {
      leading = Text(e.emoji!, style: const TextStyle(fontSize: 22));
    } else if (e.icon != null) {
      leading = Icon(e.icon, color: cs.primary);
    } else {
      leading = Icon(Icons.label_outline, color: cs.primary);
    }

    Widget trailing;
    if (widget.multi) {
      trailing = Checkbox(
        value: selected,
        onChanged: isClear
            ? null
            : (v) => setState(() {
                  if (v == true) {
                    _multi.add(e.id);
                  } else {
                    _multi.remove(e.id);
                  }
                }),
      );
    } else {
      trailing = selected
          ? Icon(Icons.check_circle, color: cs.primary)
          : const SizedBox(width: 24);
    }

    return Material(
      color: selected ? cs.primary.withValues(alpha: 0.08) : null,
      child: InkWell(
        onTap: () {
          if (widget.multi) {
            if (isClear) return;
            setState(() {
              if (_multi.contains(e.id)) {
                _multi.remove(e.id);
              } else {
                _multi.add(e.id);
              }
            });
          } else {
            setState(() => _single = isClear ? '' : e.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Center(child: leading),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isClear ? widget.clearLabel : e.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((isClear ? null : e.subtitle)?.isNotEmpty ?? false)
                      Text(
                        e.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      )
                    else if (!isClear && e.subtitle == null)
                      Text(
                        e.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                              fontFamily: 'monospace',
                            ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable trigger row for `_special` fields. Shows a preview of the current
/// value and a "Change"/"Edit" tonal button. The preview is rendered by the
/// supplied [previewBuilder] so each selector can show chips, plain text, etc.
class SpecialFieldTrigger extends StatelessWidget {
  const SpecialFieldTrigger({
    super.key,
    required this.previewBuilder,
    required this.onPressed,
    this.buttonText = 'Change',
    this.busy = false,
  });

  final WidgetBuilder previewBuilder;
  final VoidCallback onPressed;
  final String buttonText;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Builder(builder: previewBuilder)),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onPressed,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.tune, size: 16),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
