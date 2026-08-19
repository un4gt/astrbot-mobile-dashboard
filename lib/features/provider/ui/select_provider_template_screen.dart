/// Picker for a provider template, grouped by capability tab.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/type_icons.dart';
import '../../config/data/config_service.dart';
import '../data/provider_service.dart';

class SelectProviderTemplateScreen extends ConsumerWidget {
  const SelectProviderTemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(configBundleProvider);
    return DefaultTabController(
      length: providerTypes.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.trM('config.newProvider')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'All'),
              for (final t in providerTypes) Tab(text: _shortLabel(t)),
            ],
          ),
        ),
        body: bundle.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(e is ApiException ? e.message : e.toString()),
          ),
          data: (b) {
            final tpls = b.providerTemplates;
            if (tpls.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No provider templates returned by the server.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return TabBarView(
              children: [
                _buildList(context, tpls, null),
                for (final t in providerTypes) _buildList(context, tpls, t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Map<String, Map<String, dynamic>> tpls,
      String? capability) {
    final entries = tpls.entries.where((e) {
      if (capability == null) return true;
      final tpl = e.value;
      return capabilityOf(tpl) == capability;
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.trM('config.noTemplates')),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = entries[i];
        final tpl = e.value;
        final providerKey = (tpl['provider'] ?? '').toString();
        return ListTile(
          leading: Icon(providerIconFor(providerKey)),
          title: Text(e.key),
          subtitle: Text(
            [
              providerKey,
              capabilityOf(tpl) ?? '-',
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final clone = _deepClone(tpl);
            context.pushReplacement(
              '/providers/edit',
              extra: {
                'config': clone,
                'isNew': true,
                'templateName': e.key,
              },
            );
          },
        );
      },
    );
  }
}

String _shortLabel(String t) {
  switch (t) {
    case 'chat_completion':
      return 'Chat';
    case 'agent_runner':
      return 'Agent';
    case 'speech_to_text':
      return 'STT';
    case 'text_to_speech':
      return 'TTS';
    case 'embedding':
      return 'Embed';
    case 'rerank':
      return 'Rerank';
    default:
      return t;
  }
}

dynamic _deepClone(dynamic v) {
  if (v is Map) {
    return Map<String, dynamic>.from(
        v.map((k, vv) => MapEntry(k.toString(), _deepClone(vv))));
  }
  if (v is List) return v.map(_deepClone).toList();
  return v;
}
