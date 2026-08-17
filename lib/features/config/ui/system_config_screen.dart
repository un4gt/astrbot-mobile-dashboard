/// System (global) configuration editor, mobile-optimized.
///
/// Mirrors the web dashboard's ConfigPage + AstrBotCoreConfigWrapper:
///   - Top tab bar: one tab per top-level metadata group
///     (`ai_group`, `platform_group`, `plugin_group`, `ext_group`,
///     `system_group` -- whatever the server returns).
///   - Inside each tab: a vertical list of ExpansionTile sections,
///     one per subsection in `metadata[<group>].metadata.<section>`.
///   - Each section is a `ConfigForm` in schemaItems mode: item keys are
///     dotted selectors (e.g. `provider_settings.default_provider_id`)
///     resolved against the WHOLE config map, exactly like
///     AstrBotConfigV4.vue -- NOT against a per-section subtree.
///   - Sticky bottom bar: "Save" splices every section form's edited
///     whole-config back together and posts it. The server typically
///     restarts the core after a system save -- we surface a "restarting…"
///     snack so the user expects re-login.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/config_service.dart';
import '../domain/config_bundle.dart';
import '../domain/meta_translate.dart';
import '../domain/selector.dart';
import 'config_form.dart';

class SystemConfigScreen extends ConsumerStatefulWidget {
  const SystemConfigScreen({super.key});

  @override
  ConsumerState<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends ConsumerState<SystemConfigScreen>
    with TickerProviderStateMixin {
  /// Per-section form keys. `Map<sectionPath, GlobalKey>` where sectionPath is
  /// like `ai_group.agent_runner`.
  final Map<String, GlobalKey<ConfigFormState>> _formKeys = {};

  bool _saving = false;
  bool _dirty = false;

  TabController? _tabController;

  void _ensureTabs(int length) {
    if (_tabController?.length == length) return;
    final prevIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: prevIndex.clamp(0, length - 1),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  GlobalKey<ConfigFormState> _keyFor(String path) =>
      _formKeys.putIfAbsent(path, GlobalKey<ConfigFormState>.new);

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return showConfirmDialog(
      context: context,
      title: context.trM('config.discardTitle'),
      message: context.trM('config.discardMessage'),
      destructive: true,
      confirmLabel: context.trM('common.cancel'),
    );
  }

  Future<void> _save(ConfigBundle bundle) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Every section form starts from the same whole-config snapshot, so
      // each currentValue() is that snapshot plus one section's edits --
      // merging them all (later writes win) yields the union of edits.
      final next = deepCopyMap(bundle.config);
      _formKeys.forEach((path, key) {
        final state = key.currentState;
        if (state == null) return;
        deepMergeOverwrite(next, state.currentValue());
      });

      await ref.read(configServiceProvider).saveSystemConfig(next);
      ref.invalidate(systemConfigProvider);
      _dirty = false;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          context.trM('config.savedRestarting'),
        ),
        duration: const Duration(seconds: 4),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final config = ref.watch(systemConfigProvider);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (!context.mounted) return;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.trM('config.title')),
          actions: [
            IconButton(
              tooltip: context.trM('config.refresh'),
              onPressed: () async {
                if (await _confirmDiscard()) {
                  ref.invalidate(systemConfigProvider);
                }
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: config.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                e is ApiException ? e.message : e.toString(),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (bundle) {
            // Sort group entries with a stable order: known groups first.
            const knownOrder = [
              'ai_group',
              'platform_group',
              'plugin_group',
              'ext_group',
              'system_group',
            ];
            final groupEntries = bundle.metadata.entries.toList()
              ..sort((a, b) {
                final ai = knownOrder.indexOf(a.key);
                final bi = knownOrder.indexOf(b.key);
                if (ai == -1 && bi == -1) return a.key.compareTo(b.key);
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });
            _ensureTabs(groupEntries.length);
            if (groupEntries.isEmpty) {
              return const Center(child: Text('No config metadata.'));
            }
            return Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: [
                      for (final entry in groupEntries)
                        Tab(
                          text: _groupLabel(loc, entry.key, entry.value),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final entry in groupEntries)
                        _buildGroupTab(loc, entry.key, entry.value, bundle),
                    ],
                  ),
                ),
                _saveBar(bundle),
              ],
            );
          },
        ),
      ),
    );
  }

  String _groupLabel(AppLocalizations loc, String key, dynamic groupMeta) {
    if (groupMeta is Map && groupMeta['name'] is String) {
      final name = groupMeta['name'] as String;
      return translateMetaString(loc, name)?.toString() ?? key;
    }
    return key;
  }

  Widget _buildGroupTab(
    AppLocalizations loc,
    String groupKey,
    dynamic groupMeta,
    ConfigBundle bundle,
  ) {
    if (groupMeta is! Map) return const SizedBox.shrink();
    final sections = groupMeta['metadata'];
    if (sections is! Map) {
      return const Center(child: Text('No sections in this group.'));
    }
    final entries = sections.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final sectionKey = entries[i].key.toString();
        final sectionMeta = entries[i].value;
        if (sectionMeta is! Map) return const SizedBox.shrink();
        final title =
            translateMetaString(loc, sectionMeta['description'])?.toString() ??
                sectionKey;
        final hint =
            translateMetaString(loc, sectionMeta['hint'])?.toString();
        final path = '$groupKey.$sectionKey';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: hint != null && hint.isNotEmpty
                ? Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            children: [
              Listener(
                onPointerDown: (_) {
                  // Mark dirty on first user interaction within the form.
                  // Setting this lazily avoids spurious dirty flags during
                  // initial layout.
                  if (!_dirty) setState(() => _dirty = true);
                },
                child: ConfigForm(
                  key: _keyFor(path),
                  sectionMeta: Map<String, dynamic>.from(sectionMeta),
                  // Item keys are dotted selectors into the whole config
                  // (AstrBotConfigV4.vue), not a per-section subtree.
                  initial: bundle.config,
                  title: '',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _saveBar(ConfigBundle bundle) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.trM('config.unsaved'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(bundle),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(context.trM('config.save')),
            ),
          ],
        ),
      ),
    );
  }
}
