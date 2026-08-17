/// Renders a config form for a single section. Two rendering modes mirror
/// the two Vue components in the web dashboard:
///
/// - [ConfigFormMode.configKeys] (`AstrBotConfig.vue`, used by the
///   Provider/Platform/Plugin editors): iterate the *current config's keys*
///   and look up each key's metadata. Only fields that actually exist in the
///   config are shown, which keeps vendor-specific template fields (e.g.
///   rerank/TTS options) out of an OpenAI provider edit page -- exactly what
///   the web dashboard does. `hint` keys are skipped, `invisible`/`condition`
///   metadata still hides/controls items, and nested `object` values recurse
///   into sub-forms via their nested `items` metadata.
/// - [ConfigFormMode.schemaItems] (`AstrBotConfigV4.vue`, used by the core
///   config page): iterate the section's `items` schema, including
///   dotted-selector keys like `provider_settings.default_provider_id`
///   resolved against the whole config map.
///
/// The edited copy is exposed via a `GlobalKey<ConfigFormState>`.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../domain/meta_translate.dart';
import '../domain/selector.dart';
import 'widgets/config_field.dart';

enum ConfigFormMode {
  /// Iterate metadata `items` (AstrBotConfigV4.vue behavior).
  schemaItems,

  /// Iterate the config map's own keys (AstrBotConfig.vue behavior).
  configKeys,
}

class ConfigForm extends StatefulWidget {
  /// Section metadata, e.g. `metadata.platform_group.metadata.platform`.
  /// Must contain `type: 'object'` (or `config_template`) and `items: {...}`.
  final Map<String, dynamic> sectionMeta;

  /// Initial config values. In [ConfigFormMode.schemaItems] mode this is the
  /// whole config map the dotted selectors resolve against.
  final Map<String, dynamic> initial;

  /// Optional override for the section title (otherwise pulled from
  /// `sectionMeta.description`).
  final String? title;

  /// Rendering mode; see [ConfigFormMode].
  final ConfigFormMode mode;

  /// Fires with the whole edited map after every change. Used by nested
  /// forms so the parent's copy of the nested subtree stays in sync.
  final ValueChanged<Map<String, dynamic>>? onChanged;

  const ConfigForm({
    super.key,
    required this.sectionMeta,
    required this.initial,
    this.title,
    this.mode = ConfigFormMode.schemaItems,
    this.onChanged,
  });

  @override
  State<ConfigForm> createState() => ConfigFormState();
}

class ConfigFormState extends State<ConfigForm> {
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = deepCopyMap(widget.initial);
  }

  /// Public read of the current edited map. Parent calls this on save.
  Map<String, dynamic> currentValue() => deepCopyMap(_data);

  void _setField(String selector, dynamic value) {
    setState(() {
      if (widget.mode == ConfigFormMode.configKeys && !selector.contains('.')) {
        _data[selector] = value;
      } else {
        setValueBySelector(_data, selector, value);
      }
    });
    widget.onChanged?.call(deepCopyMap(_data));
  }

  Map<String, dynamic> get _items {
    final items = widget.sectionMeta['items'];
    return items is Map ? Map<String, dynamic>.from(items) : const {};
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final children = <Widget>[];

    final secDesc = widget.title ??
        translateMetaString(loc, widget.sectionMeta['description'])?.toString();
    final secHint = translateMetaString(loc, widget.sectionMeta['hint'])
        ?.toString();
    if ((secDesc?.isNotEmpty ?? false) || (secHint?.isNotEmpty ?? false)) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (secDesc?.isNotEmpty ?? false)
              Text(
                secDesc!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (secHint?.isNotEmpty ?? false)
              Text(
                secHint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ));
    }

    final fields = widget.mode == ConfigFormMode.configKeys
        ? _buildConfigKeys()
        : _buildSchemaItems();

    if (fields.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.trM('config.noFields'),
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...children, ...fields],
    );
  }

  /// AstrBotConfig.vue behavior: one row per key of the live config map.
  List<Widget> _buildConfigKeys() {
    final items = _items;
    final children = <Widget>[];
    for (final entry in _data.entries) {
      final key = entry.key;
      // Template-level hint banners are not editable fields.
      if (key == 'hint') continue;
      final rawMeta = items[key];
      Map<String, dynamic> meta;
      if (rawMeta is Map) {
        meta = Map<String, dynamic>.from(rawMeta);
        if (meta['invisible'] == true) continue;
        final cond = meta['condition'];
        if (cond is Map &&
            !conditionSatisfied(Map<String, dynamic>.from(cond), _data)) {
          continue;
        }
      } else {
        meta = _inferMeta(entry.value);
      }

      final value = entry.value;
      if (meta['type'] == 'object' && meta['items'] is Map && value is Map) {
        children.add(_NestedForm(
          sectionMeta: meta,
          initial: Map<String, dynamic>.from(value),
          onChanged: (v) => _setField(key, v),
        ));
        continue;
      }
      children.add(ConfigField(
        key: ValueKey('field_$key'),
        itemKey: key,
        itemMeta: meta,
        value: value,
        onChanged: (v) => _setField(key, v),
      ));
    }
    return children;
  }

  /// AstrBotConfigV4.vue behavior: one row per schema item, values resolved
  /// from the whole config via dotted selectors.
  List<Widget> _buildSchemaItems() {
    final children = <Widget>[];
    for (final entry in _items.entries) {
      final itemKey = entry.key.toString();
      final raw = entry.value;
      if (raw is! Map) continue;
      final meta = Map<String, dynamic>.from(raw);
      if (meta['invisible'] == true) continue;
      final cond = meta['condition'];
      if (cond is Map &&
          !conditionSatisfied(Map<String, dynamic>.from(cond), _data)) {
        continue;
      }

      final value = getValueBySelector(_data, itemKey);
      if (meta['type'] == 'object' && meta['items'] is Map && value is Map) {
        children.add(_NestedForm(
          sectionMeta: meta,
          initial: Map<String, dynamic>.from(value),
          onChanged: (v) => _setField(itemKey, v),
        ));
        continue;
      }
      children.add(ConfigField(
        key: ValueKey('field_$itemKey'),
        itemKey: itemKey,
        itemMeta: meta,
        value: value,
        onChanged: (v) => _setField(itemKey, v),
      ));
    }
    return children;
  }

  Map<String, dynamic> _inferMeta(dynamic value) => {
        'type': value is bool
            ? 'bool'
            : value is int
                ? 'int'
                : value is double
                    ? 'float'
                    : value is List
                        ? 'list'
                        : value is Map
                            ? 'dict'
                            : 'string',
      };
}

/// Indented sub-form for nested `object` items (e.g. a provider's
/// `model_config`). Recursion keeps iterating config keys, mirroring
/// AstrBotConfig.vue's recursive self-usage; edits propagate up through
/// [onChanged] so the parent's copy of the subtree stays current.
class _NestedForm extends StatelessWidget {
  const _NestedForm({
    required this.sectionMeta,
    required this.initial,
    required this.onChanged,
  });

  final Map<String, dynamic> sectionMeta;
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final desc =
        translateMetaString(loc, sectionMeta['description'])?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                desc,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ConfigForm(
              sectionMeta: sectionMeta,
              initial: initial,
              mode: ConfigFormMode.configKeys,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
