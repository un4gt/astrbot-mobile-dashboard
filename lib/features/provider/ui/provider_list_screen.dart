/// Provider list with capability tabs (chat_completion, agent_runner, STT,
/// TTS, embedding, rerank). Mirrors `views/ProviderPage.vue`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/item_card.dart';
import '../../../shared/widgets/type_icons.dart';
import '../../config/data/config_service.dart';
import '../data/provider_service.dart';

const _tabKeys = <String>[
  'all',
  'chat_completion',
  'agent_runner',
  'speech_to_text',
  'text_to_speech',
  'embedding',
  'rerank',
];

String _tabLabel(BuildContext context, String key) {
  switch (key) {
    case 'all':
      return context.trM('providers.tabs.all');
    case 'chat_completion':
      return context.trM('providers.tabs.chat');
    case 'agent_runner':
      return context.trM('providers.tabs.agent');
    case 'speech_to_text':
      return context.trM('providers.tabs.stt');
    case 'text_to_speech':
      return context.trM('providers.tabs.tts');
    case 'embedding':
      return context.trM('providers.tabs.embedding');
    case 'rerank':
      return context.trM('providers.tabs.rerank');
    default:
      return key;
  }
}

class ProviderListScreen extends ConsumerStatefulWidget {
  const ProviderListScreen({super.key});

  @override
  ConsumerState<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends ConsumerState<ProviderListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl =
      TabController(length: _tabKeys.length, vsync: this);

  final Map<String, ProviderStatus?> _statuses = {};

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _testAvailability(Map<String, dynamic> p) async {
    final id = (p['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() => _statuses[id] = null);
    try {
      final s = await ref.read(providerServiceProvider).checkOne(id);
      if (!mounted) return;
      setState(() => _statuses[id] = s);
      _snack(
        s.status == 'available'
            ? '$id ${context.trM('providers.available')}'
            : (s.error ?? context.trM('providers.unavailable')),
        error: s.status != 'available',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _statuses[id] = ProviderStatus(
            id: id,
            name: id,
            status: 'unavailable',
            error: e.message,
          ));
      _snack(e.message, error: true);
    }
  }

  Future<void> _toggle(Map<String, dynamic> p, bool enable) async {
    final updated = Map<String, dynamic>.from(p)..['enable'] = enable;
    try {
      await ref
          .read(providerServiceProvider)
          .update((p['id'] ?? '').toString(), updated);
      ref.invalidate(configBundleProvider);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final id = (p['id'] ?? '').toString();
    final ok = await showConfirmDialog(
      context: context,
      title: context.trM('providers.deleteTitle'),
      message: context.trM('providers.deleteMessage', params: {'id': id}),
      destructive: true,
      confirmLabel: context.trM('common.delete'),
      cancelLabel: context.trM('common.cancel'),
    );
    if (!ok) return;
    try {
      await ref.read(providerServiceProvider).delete(id);
      ref.invalidate(configBundleProvider);
      if (!mounted) return;
      _snack(context.trM('providers.deleted', params: {'id': id}));
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  List<Map<String, dynamic>> _filtered(
      List<Map<String, dynamic>> all, String tabKey) {
    if (tabKey == 'all') return all;
    return all.where((p) => capabilityOf(p) == tabKey).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(configBundleProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('providers.title')),
        actions: [
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: () => ref.invalidate(configBundleProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: [for (final t in _tabKeys) Tab(text: _tabLabel(context, t))],
        ),
      ),
      floatingActionButton: bundle.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/providers/new'),
              icon: const Icon(Icons.add),
              label: Text(context.trM('providers.add')),
            )
          : null,
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? e.message : e.toString()),
        ),
        data: (b) {
          final providers = b.providers;
          return TabBarView(
            controller: _tabCtrl,
            children: [
              for (final tabKey in _tabKeys)
                _buildList(_filtered(providers, tabKey)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.trM('providers.empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(configBundleProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final p = list[i];
          final id = (p['id'] ?? '').toString();
          final providerKey = (p['provider'] ?? '').toString();
          final capability = capabilityOf(p) ?? '-';
          final modelConfig = p['model_config'];
          final model =
              modelConfig is Map ? modelConfig['model']?.toString() : null;
          final hasStatusEntry = _statuses.containsKey(id);
          final status = _statuses[id];
          final testing = hasStatusEntry && status == null;
          String? statusLabel;
          Color? statusColor;
          if (testing) {
            statusLabel = context.trM('providers.testing');
            statusColor = Theme.of(context).colorScheme.outline;
          } else if (status != null) {
            statusLabel = status.status == 'available'
                ? context.trM('providers.available')
                : context.trM('providers.unavailable');
            statusColor = status.status == 'available'
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error;
          }
          return ItemCard(
            title: id.isEmpty ? '(no id)' : id,
            subtitle: [providerKey, capability, ?model]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            icon: providerIconFor(providerKey),
            statusLabel: statusLabel,
            statusColor: statusColor,
            enabled: p['enable'] == true,
            onEnabledChanged: (v) => _toggle(p, v),
            onTap: () => context.push('/providers/edit', extra: p),
            actions: [
              ItemCardAction(
                icon: Icons.bolt_outlined,
                label: testing
                    ? context.trM('providers.testing')
                    : context.trM('providers.testAvailability'),
                onSelected: testing ? () {} : () => _testAvailability(p),
              ),
              ItemCardAction(
                icon: Icons.edit_outlined,
                label: context.trM('common.edit'),
                onSelected: () => context.push('/providers/edit', extra: p),
              ),
              ItemCardAction(
                icon: Icons.delete_outline,
                label: context.trM('common.delete'),
                destructive: true,
                onSelected: () => _delete(p),
              ),
            ],
          );
        },
      ),
    );
  }
}
