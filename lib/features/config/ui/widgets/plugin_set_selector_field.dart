/// Plugin-set selector. `select_plugin_set` stores a `List<String>` with
/// special wildcard semantics (per `PluginSetSelector.vue`):
///   - `[]`        -> "Disable all plugins"
///   - `['*']`     -> "Enable all plugins"
///   - `['a','b']` -> "Custom (only these plugins)"
library;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../plugin/data/plugin_service.dart';
import 'special_picker_sheets.dart';

enum _PluginMode { all, none, custom }

class PluginSetSelectorField extends ConsumerWidget {
  const PluginSetSelectorField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  List<String> get _list {
    if (value is List) {
      return (value as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  _PluginMode _modeOf(List<String> list) {
    if (list.isEmpty) return _PluginMode.none;
    if (list.length == 1 && list.first == '*') return _PluginMode.all;
    return _PluginMode.custom;
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final plugins =
        ref.read(installedPluginsProvider).valueOrNull?.plugins ??
            const <InstalledPlugin>[];
    // Match the Vue selector: only show activated, non-reserved plugins.
    final activeUserPlugins = plugins
        .where((p) => p.activated && !p.reserved)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    var current = _list;
    var mode = _modeOf(current);
    var selected = mode == _PluginMode.custom ? Set<String>.from(current) : <String>{};

    final result = await showModalBottomSheet<List<String>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final mq = MediaQuery.of(sheetCtx);
        return StatefulBuilder(
          builder: (sheetCtx, setState) => Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: SizedBox(
              height: mq.size.height * 0.85,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetCtx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('Plugin set',
                            style: Theme.of(sheetCtx).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<_PluginMode>(
                    groupValue: mode,
                    onChanged: (v) {
                      if (v != null) setState(() => mode = v);
                    },
                    child: Column(
                      children: [
                        RadioListTile<_PluginMode>(
                          value: _PluginMode.all,
                          title: Text(context.trM('common.enableAllPlugins')),
                          subtitle: Text(context.trM('common.enableAllStored')),
                        ),
                        RadioListTile<_PluginMode>(
                          value: _PluginMode.none,
                          title: Text(context.trM('common.disableAllPlugins')),
                          subtitle: Text(context.trM('common.disableAllStored')),
                        ),
                        RadioListTile<_PluginMode>(
                          value: _PluginMode.custom,
                          title: Text(context.trM('common.customSelection')),
                          subtitle: Text(
                            activeUserPlugins.isEmpty
                                ? 'No activated user plugins'
                                : '${selected.length} of ${activeUserPlugins.length} chosen',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (mode == _PluginMode.custom)
                    Expanded(
                      child: ListView(
                        children: [
                          for (final p in activeUserPlugins)
                            CheckboxListTile(
                              value: selected.contains(p.name),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  selected.add(p.name);
                                } else {
                                  selected.remove(p.name);
                                }
                              }),
                              title: Text(p.name),
                              subtitle: Text(
                                [
                                  if (p.version.isNotEmpty) 'v${p.version}',
                                  if (p.author.isNotEmpty) p.author,
                                ].join(' · '),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: Text(context.trM('common.cancel')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              List<String> next;
                              switch (mode) {
                                case _PluginMode.all:
                                  next = const ['*'];
                                  break;
                                case _PluginMode.none:
                                  next = const [];
                                  break;
                                case _PluginMode.custom:
                                  next = selected.toList()..sort();
                                  break;
                              }
                              Navigator.pop(sheetCtx, next);
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
          ),
        );
      },
    );

    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(installedPluginsProvider); // trigger fetch
    return SpecialFieldTrigger(
      buttonText: 'Edit set',
      onPressed: () => _open(context, ref),
      previewBuilder: (ctx) {
        final list = _list;
        final mode = _modeOf(list);
        switch (mode) {
          case _PluginMode.all:
            return Text(context.trM('common.allPlugins'));
          case _PluginMode.none:
            return Text(
              '(none selected)',
              style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
            );
          case _PluginMode.custom:
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final n in list.take(4))
                  Chip(
                    label: Text(n),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (list.length > 4)
                  Chip(
                    label: Text('+${list.length - 4}'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            );
        }
      },
    );
  }
}
