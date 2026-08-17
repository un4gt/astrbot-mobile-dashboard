/// Dispatcher widget that renders a single field based on its metadata.
///
/// Covers basic types (string/int/float/bool/text/list/dict/options) and the
/// `_special` selectors (provider variants, persona, knowledge base, plugin
/// set). `_special` not yet supported (e.g. `t2i_template`) falls through
/// to a read-only placeholder that still surfaces the current value.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../domain/meta_translate.dart';
import 'dict_config_field.dart';
import 'kb_selector_field.dart';
import 'list_config_field.dart';
import 'persona_selector_field.dart';
import 'plugin_set_selector_field.dart';
import 'provider_selector_field.dart';

class ConfigField extends StatelessWidget {
  const ConfigField({
    super.key,
    required this.itemKey,
    required this.itemMeta,
    required this.value,
    required this.onChanged,
  });

  final String itemKey;
  final Map<String, dynamic> itemMeta;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  bool get _readonly => itemMeta['readonly'] == true;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final descRaw = itemMeta['description'];
    final hintRaw = itemMeta['hint'];
    final desc = translateMetaString(loc, descRaw);
    final hint = translateMetaString(loc, hintRaw);
    final type = (itemMeta['type'] ?? '').toString();
    final special = itemMeta['_special']?.toString();
    final hasOptions = itemMeta['options'] is List;

    final label = (desc != null && desc.toString().isNotEmpty)
        ? desc.toString()
        : itemKey;
    final fieldKey = ValueKey('${itemKey}_${value.runtimeType}');

    Widget input;
    if (special != null && special.isNotEmpty) {
      input = _buildSpecial(
        fieldKey: fieldKey,
        special: special,
        value: value,
        onChanged: onChanged,
      );
    } else if (hasOptions) {
      input = _OptionsField(
        key: fieldKey,
        meta: itemMeta,
        value: value,
        readonly: _readonly,
        onChanged: onChanged,
      );
    } else {
      switch (type) {
        case 'bool':
          input = _BoolField(
            key: fieldKey,
            value: value == true,
            readonly: _readonly,
            onChanged: onChanged,
          );
          break;
        case 'int':
          input = _NumField(
            key: fieldKey,
            value: value,
            integer: true,
            readonly: _readonly,
            onChanged: onChanged,
          );
          break;
        case 'float':
          input = _NumField(
            key: fieldKey,
            value: value,
            integer: false,
            readonly: _readonly,
            onChanged: onChanged,
          );
          break;
        case 'text':
          input = _TextField(
            key: fieldKey,
            value: value,
            multiline: true,
            readonly: _readonly,
            onChanged: onChanged,
          );
          break;
        case 'list':
          input = ListConfigField(
            key: fieldKey,
            value: value is List ? List<dynamic>.from(value) : const [],
            label: label,
            onChanged: onChanged,
          );
          break;
        case 'dict':
          input = DictConfigField(
            key: fieldKey,
            value: value is Map
                ? Map<String, dynamic>.from(value)
                : const <String, dynamic>{},
            label: label,
            onChanged: onChanged,
          );
          break;
        case 'string':
        default:
          input = _TextField(
            key: fieldKey,
            value: value,
            multiline: false,
            readonly: _readonly,
            onChanged: onChanged,
          );
      }
    }

    final hintWidget = (hint != null && hint.toString().isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              (itemMeta['obvious_hint'] == true ? '‼️ ' : '') + hint.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          // Technical key as a caption line: full width means long dotted
          // keys wrap at readable positions instead of stacking vertically
          // when squeezed next to the label.
          Text(
            itemKey,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
          ),
          ?hintWidget,
          const SizedBox(height: 6),
          input,
        ],
      ),
    );
  }

  /// Dispatch by `_special` value to the right selector field. Unknown
  /// values fall back to a read-only placeholder so the user can still see
  /// the underlying value.
  static Widget _buildSpecial({
    required ValueKey fieldKey,
    required String special,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    final name = special.split(':').first;
    switch (name) {
      case 'select_provider':
      case 'select_provider_stt':
      case 'select_provider_tts':
      case 'provider_pool':
      case 'select_agent_runner_provider':
        return ProviderSelectorField(
          key: fieldKey,
          special: special,
          value: value,
          onChanged: onChanged,
        );
      case 'select_persona':
      case 'persona_pool':
        return PersonaSelectorField(
          key: fieldKey,
          special: special,
          value: value,
          onChanged: onChanged,
        );
      case 'select_knowledgebase':
        return KbSelectorField(
          key: fieldKey,
          value: value,
          onChanged: onChanged,
        );
      case 'select_plugin_set':
        return PluginSetSelectorField(
          key: fieldKey,
          value: value,
          onChanged: onChanged,
        );
      default:
        return _SpecialPlaceholder(
          key: fieldKey,
          special: special,
          currentValue: value?.toString(),
        );
    }
  }
}

class _BoolField extends StatelessWidget {
  const _BoolField({
    super.key,
    required this.value,
    required this.readonly,
    required this.onChanged,
  });
  final bool value;
  final bool readonly;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Switch(
        value: value,
        onChanged: readonly ? null : (v) => onChanged(v),
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    super.key,
    required this.value,
    required this.multiline,
    required this.readonly,
    required this.onChanged,
  });
  final dynamic value;
  final bool multiline;
  final bool readonly;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      readOnly: widget.readonly,
      maxLines: widget.multiline ? 5 : 1,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _NumField extends StatefulWidget {
  const _NumField({
    super.key,
    required this.value,
    required this.integer,
    required this.readonly,
    required this.onChanged,
  });
  final dynamic value;
  final bool integer;
  final bool readonly;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _emit(String s) {
    if (s.isEmpty) {
      widget.onChanged(null);
      return;
    }
    if (widget.integer) {
      final v = int.tryParse(s);
      if (v != null) widget.onChanged(v);
    } else {
      final v = double.tryParse(s);
      if (v != null) widget.onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      readOnly: widget.readonly,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !widget.integer,
        signed: true,
      ),
      inputFormatters: widget.integer
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))]
          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-eE]'))],
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: _emit,
    );
  }
}

class _OptionsField extends StatelessWidget {
  const _OptionsField({
    super.key,
    required this.meta,
    required this.value,
    required this.readonly,
    required this.onChanged,
  });
  final Map<String, dynamic> meta;
  final dynamic value;
  final bool readonly;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final options = (meta['options'] as List).toList();
    final labels = translateMetaLabels(loc, meta['labels']);
    return DropdownButtonFormField<dynamic>(
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: readonly ? null : onChanged,
      items: [
        for (var i = 0; i < options.length; i++)
          DropdownMenuItem(
            value: options[i],
            child: Text(
              labels != null && i < labels.length
                  ? labels[i]
                  : options[i].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _SpecialPlaceholder extends StatelessWidget {
  const _SpecialPlaceholder({
    super.key,
    required this.special,
    required this.currentValue,
  });
  final String special;
  final String? currentValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(8),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentValue?.isNotEmpty == true ? currentValue : '(unset)'}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '_special: $special  -  picker arrives in Phase 4',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
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
