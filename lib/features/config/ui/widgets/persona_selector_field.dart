/// Persona selector. Two `_special` variants -- both store a single string
/// (mirrors `PersonaSelector.vue`):
///   - select_persona
///   - persona_pool          (different button label)
library;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../persona/data/persona_service.dart';
import 'special_picker_sheets.dart';

class PersonaSelectorField extends ConsumerWidget {
  const PersonaSelectorField({
    super.key,
    required this.special,
    required this.value,
    required this.onChanged,
  });

  final String special;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  String get _buttonText =>
      special == 'persona_pool' ? 'Choose pool' : 'Choose persona';

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final personas = ref.read(personasProvider).valueOrNull ?? const <Persona>[];
    final entries = [
      for (final p in personas)
        PickerEntry(
          id: p.id,
          title: p.id == 'default' ? 'Default persona' : p.id,
          subtitle: p.systemPrompt.isEmpty
              ? null
              : p.systemPrompt.length > 100
                  ? '${p.systemPrompt.substring(0, 100)}…'
                  : p.systemPrompt,
          icon: Icons.face_outlined,
        ),
    ];
    final result = await showSinglePickerSheet(
      context: context,
      title: context.trM('common.choosePersona'),
      entries: entries,
      currentValue: value?.toString() ?? '',
      emptyHint: 'No personas yet. Create one from More -> Persona.',
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger a fetch in the background so the picker has data on first open.
    ref.watch(personasProvider);
    return SpecialFieldTrigger(
      buttonText: _buttonText,
      onPressed: () => _open(context, ref),
      previewBuilder: (ctx) {
        final v = value?.toString() ?? '';
        if (v.isEmpty) {
          return Text(
            '(none selected)',
            style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
          );
        }
        return Text(
          v == 'default' ? 'Default persona' : v,
          style: const TextStyle(fontFamily: 'monospace'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
