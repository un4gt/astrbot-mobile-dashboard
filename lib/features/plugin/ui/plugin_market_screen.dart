/// Plugin marketplace browse + install. Mirrors the marketplace tab from
/// `views/ExtensionPage.vue` -- search, install via URL.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../data/plugin_service.dart';

class PluginMarketScreen extends ConsumerStatefulWidget {
  const PluginMarketScreen({super.key});

  @override
  ConsumerState<PluginMarketScreen> createState() => _PluginMarketScreenState();
}

class _PluginMarketScreenState extends ConsumerState<PluginMarketScreen> {
  String _query = '';

  Future<void> _install(BuildContext ctx, MarketPlugin p) async {
    final repo = p.repo;
    if (repo == null || repo.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(context.trM('plugins.noRepoUrl'))),
      );
      return;
    }
    try {
      await ref.read(pluginServiceProvider).installFromUrl(repo);
      ref.invalidate(installedPluginsProvider);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(ctx.trM('plugins.installing', params: {'name': p.name}))),
        );
      }
    } on ApiException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(pluginMarketProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('plugins.marketTitle')),
        actions: [
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: () async {
              // Force refresh from server.
              ref.invalidate(pluginMarketProvider);
              await ref.read(pluginServiceProvider).listMarket(forceRefresh: true);
              ref.invalidate(pluginMarketProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: context.trM('plugins.searchPlugins'),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: market.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(e is ApiException ? e.message : e.toString())),
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list.where((p) {
                        return p.name.toLowerCase().contains(_query) ||
                            p.description.toLowerCase().contains(_query) ||
                            p.author.toLowerCase().contains(_query) ||
                            p.tags.any((t) => t.toLowerCase().contains(_query));
                      }).toList();
                if (filtered.isEmpty) {
                  return Center(child: Text(context.trM('plugins.noMatch')));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (p.version.isNotEmpty)
                                  Text(
                                    'v${p.version}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            if (p.author.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'by ${p.author}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (p.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  p.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (p.tags.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final t in p.tags)
                                    Chip(
                                      label: Text(t),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (p.repo != null && p.repo!.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () =>
                                        launchUrl(Uri.parse(p.repo!)),
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(context.trM('plugins.repoLabel')),
                                  ),
                                TextButton.icon(
                                  onPressed: () => context.push(
                                    '/plugins/market/readme',
                                    extra: {'name': p.name, 'repo': p.repo},
                                  ),
                                  icon: const Icon(Icons.description_outlined),
                                  label: Text(context.trM('plugins.readme')),
                                ),
                                const Spacer(),
                                FilledButton.tonalIcon(
                                  onPressed: () => _install(context, p),
                                  icon: const Icon(Icons.download),
                                  label: Text(context.trM('plugins.installLabel')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
