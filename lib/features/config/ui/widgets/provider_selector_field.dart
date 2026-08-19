/// Provider selector field. Supports five `_special` variants (all of which
/// store a SINGLE provider id as a string -- mirrors `ProviderSelector.vue`):
///   - select_provider                      -> chat_completion
///   - select_provider_stt                  -> speech_to_text
///   - select_provider_tts                  -> text_to_speech
///   - provider_pool                        -> chat_completion (re-labeled)
///   - select_agent_runner_provider:<sub>   -> agent_runner, optional subtype
library;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/type_icons.dart';
import '../../../config/data/config_service.dart';
import '../../../provider/data/provider_service.dart';
import 'special_picker_sheets.dart';

class ProviderSelectorField extends ConsumerWidget {
  const ProviderSelectorField({
    super.key,
    required this.special,
    required this.value,
    required this.onChanged,
  });

  /// Raw `_special` string (with optional `:subtype`).
  final String special;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  String get _capability {
    final name = special.split(':').first;
    switch (name) {
      case 'select_provider_stt':
        return 'speech_to_text';
      case 'select_provider_tts':
        return 'text_to_speech';
      case 'select_agent_runner_provider':
        return 'agent_runner';
      case 'select_provider':
      case 'provider_pool':
      default:
        return 'chat_completion';
    }
  }

  String get _subtype {
    final parts = special.split(':');
    return parts.length > 1 ? parts.skip(1).join(':') : '';
  }

  String get _buttonText {
    final name = special.split(':').first;
    switch (name) {
      case 'provider_pool':
        return 'Choose pool';
      default:
        return 'Choose provider';
    }
  }

  bool _matchesSubtype(Map<String, dynamic> p) {
    if (_subtype.isEmpty) return true;
    final s = _subtype.toLowerCase();
    final fields = [p['type'], p['provider'], p['id']]
        .map((v) => v?.toString().toLowerCase() ?? '')
        .toList();
    return fields.any((f) => f == s);
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final bundle = ref.read(configBundleProvider).valueOrNull;
    final all = bundle?.providers ?? const <Map<String, dynamic>>[];
    final filtered = all.where((p) {
      final cap = capabilityOf(p);
      if (cap != _capability) return false;
      if (_capability == 'agent_runner') return _matchesSubtype(p);
      return true;
    }).toList();

    final entries = [
      for (final p in filtered)
        PickerEntry(
          id: (p['id'] ?? '').toString(),
          title: (p['id'] ?? '(no id)').toString(),
          subtitle: _subtitleOf(p),
          icon: providerIconFor((p['provider'] ?? '').toString()),
        ),
    ];

    final result = await showSinglePickerSheet(
      context: context,
      title: context.trM('common.chooseProvider'),
      entries: entries,
      currentValue: value?.toString() ?? '',
      emptyHint:
          'No providers configured for ${_capability.replaceAll("_", " ")}.',
    );
    if (result != null) onChanged(result);
  }

  String _subtitleOf(Map<String, dynamic> p) {
    final providerKey = (p['provider'] ?? '').toString();
    final mc = p['model_config'];
    final model = mc is Map ? mc['model']?.toString() : null;
    return [
      providerKey,
      capabilityOf(p) ?? '-',
      if (model != null && model.isNotEmpty) model,
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          v,
          style: const TextStyle(fontFamily: 'monospace'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
