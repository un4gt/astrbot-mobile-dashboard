/// Knowledge-base selector. `select_knowledgebase` stores a `List<String>` of
/// kb_name (multi-select) -- per `KnowledgeBaseSelector.vue`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../kb/data/kb_service.dart';
import 'special_picker_sheets.dart';

class KbSelectorField extends ConsumerWidget {
  const KbSelectorField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  List<String> get _selected {
    if (value is List) {
      return (value as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final kbs = ref.read(kbListProvider).valueOrNull ?? const <KnowledgeBase>[];
    final entries = [
      for (final kb in kbs)
        PickerEntry(
          id: kb.name,
          title: kb.name,
          subtitle: [
            if (kb.description.isNotEmpty) kb.description,
            '${kb.documentCount} doc(s) · ${kb.chunkCount} chunk(s)',
          ].join(' · '),
          emoji: kb.emojiIcon,
        ),
    ];
    final result = await showMultiPickerSheet(
      context: context,
      title: 'Select knowledge bases',
      entries: entries,
      currentValues: _selected,
      emptyHint: 'No knowledge bases yet.',
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(kbListProvider); // trigger fetch
    return SpecialFieldTrigger(
      buttonText: 'Choose KBs',
      onPressed: () => _open(context, ref),
      previewBuilder: (ctx) {
        final selected = _selected;
        if (selected.isEmpty) {
          return Text(
            '(none selected)',
            style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
          );
        }
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final name in selected.take(4))
              Chip(
                label: Text(name),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (selected.length > 4)
              Chip(
                label: Text('+${selected.length - 4}'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        );
      },
    );
  }
}
