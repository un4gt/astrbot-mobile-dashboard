/// Session custom-rules list. Each row is one UMO with a summary of
/// override types (service / provider / plugin / KB). FAB pulls active
/// UMOs from the server, lets the user pick one to add a rule for.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/session_service.dart';

class SessionRulesScreen extends ConsumerWidget {
  const SessionRulesScreen({super.key});

  Future<void> _addRule(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(sessionServiceProvider);
    List<String> umos;
    try {
      umos = await svc.activeUmos();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    final existing = ref.read(sessionRulesProvider).valueOrNull?.rules
            .map((r) => r.umo)
            .toSet() ??
        const <String>{};
    final candidates = umos.where((u) => !existing.contains(u)).toList()..sort();

    if (!context.mounted) return;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Pick an active UMO',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              if (candidates.isEmpty)
                Expanded(
                  child: Center(child: Text(context.trM('session.noUmos'))),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final umo = candidates[i];
                      return ListTile(
                        leading: const Icon(Icons.tag),
                        title: Text(
                          umo,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        onTap: () => Navigator.pop(sheetCtx, umo),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    if (!context.mounted) return;
    context.push('/more/session/edit', extra: {
      'umo': selected,
      'rules': <String, dynamic>{},
    });
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, SessionRule rule) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete rule?',
      message: 'All overrides for ${rule.umo} will be removed.',
      destructive: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(sessionServiceProvider).deleteRule(umo: rule.umo);
      ref.invalidate(sessionRulesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  String _ruleSummary(Map<String, dynamic> rules) {
    final overrides = <String>[];
    if (rules.containsKey('session_service_config')) overrides.add('service');
    if (rules.containsKey('provider_perf_chat_completion')) overrides.add('chat');
    if (rules.containsKey('provider_perf_speech_to_text')) overrides.add('stt');
    if (rules.containsKey('provider_perf_text_to_speech')) overrides.add('tts');
    if (rules.containsKey('session_plugin_config')) overrides.add('plugins');
    if (rules.containsKey('kb_config')) overrides.add('kb');
    return overrides.isEmpty ? '(no overrides)' : overrides.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(sessionRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('session.rulesTitle')),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(sessionRulesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRule(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.trM('session.addRule')),
      ),
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is ApiException ? e.message : e.toString()),
          ),
        ),
        data: (data) {
          if (data.rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No session-specific rules yet.\nTap "Add rule" to override settings for one UMO.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionRulesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
              itemCount: data.rules.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = data.rules[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    child: Icon(
                      r.messageType == 'GroupMessage'
                          ? Icons.groups_outlined
                          : Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    r.umo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  subtitle: Text(_ruleSummary(r.rules)),
                  onTap: () => context.push('/more/session/edit', extra: {
                    'umo': r.umo,
                    'rules': r.rules,
                    'available_personas': data.availablePersonas,
                    'available_chat_providers': data.availableChatProviders,
                    'available_stt_providers': data.availableSttProviders,
                    'available_tts_providers': data.availableTtsProviders,
                    'available_plugins': data.availablePlugins,
                    'available_kbs': data.availableKbs,
                  }),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, r),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
