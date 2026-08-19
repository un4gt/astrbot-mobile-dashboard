/// Installed plugins list. Tap to view detail/config; toggle to enable/disable.
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/item_card.dart';
import '../data/plugin_service.dart';

class InstalledPluginsScreen extends ConsumerStatefulWidget {
  const InstalledPluginsScreen({super.key});

  @override
  ConsumerState<InstalledPluginsScreen> createState() =>
      _InstalledPluginsScreenState();
}

class _InstalledPluginsScreenState
    extends ConsumerState<InstalledPluginsScreen> {
  /// Web dashboard parity: built-in (reserved) plugins stay hidden until the
  /// user opts in with the eye toggle.
  bool _showReserved = false;

  /// Last plugin-load failure notice already shown (dedupes across rebuilds).
  String? _loadErrorShown;

  /// Plugin logos come back as `/api/file/<token>` -- relative to the active
  /// server. Tokens are short-lived; a failed load falls back to the icon.
  String? _logoUrl(InstalledPlugin p) {
    final logo = p.logo;
    if (logo == null) return null;
    if (logo.startsWith('http')) return logo;
    final base = ref.read(baseUrlProvider);
    if (base == null || base.isEmpty) return null;
    return '$base$logo';
  }

  void _showLoadError(String message) {
    if (message == _loadErrorShown) return;
    _loadErrorShown = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.error_outline,
              color: Theme.of(ctx).colorScheme.error),
          title: Text(context.trM('plugins.loadErrorTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message),
              const SizedBox(height: 12),
              Text(
                context.trM('plugins.loadErrorHint'),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.trM('common.close')),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _toggle(BuildContext ctx, WidgetRef ref, InstalledPlugin p,
      bool active) async {
    try {
      await ref.read(pluginServiceProvider).setActivated(p.name, active);
      ref.invalidate(installedPluginsProvider);
    } on ApiException catch (e) {
      if (ctx.mounted) _snack(ctx, e.message, error: true);
    }
  }

  Future<void> _reload(BuildContext ctx, WidgetRef ref, InstalledPlugin p) async {
    try {
      await ref.read(pluginServiceProvider).reload(p.name);
      ref.invalidate(installedPluginsProvider);
      if (ctx.mounted) _snack(ctx, 'Reloaded ${p.name}.');
    } on ApiException catch (e) {
      if (ctx.mounted) _snack(ctx, e.message, error: true);
    }
  }

  Future<void> _update(BuildContext ctx, WidgetRef ref, InstalledPlugin p) async {
    try {
      await ref.read(pluginServiceProvider).update(p.name);
      ref.invalidate(installedPluginsProvider);
      if (ctx.mounted) _snack(ctx, 'Update triggered for ${p.name}.');
    } on ApiException catch (e) {
      if (ctx.mounted) _snack(ctx, e.message, error: true);
    }
  }

  Future<void> _uninstall(
      BuildContext ctx, WidgetRef ref, InstalledPlugin p) async {
    final ok = await showConfirmDialog(
      context: ctx,
      title: 'Uninstall plugin?',
      message:
          '"${p.name}" will be removed. This does not delete plugin config or data files.',
      destructive: true,
      confirmLabel: 'Uninstall',
    );
    if (!ok) return;
    try {
      await ref.read(pluginServiceProvider).uninstall(p.name);
      ref.invalidate(installedPluginsProvider);
      if (ctx.mounted) _snack(ctx, 'Uninstalled ${p.name}.');
    } on ApiException catch (e) {
      if (ctx.mounted) _snack(ctx, e.message, error: true);
    }
  }

  void _snack(BuildContext ctx, String msg, {bool error = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(ctx).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final installed = ref.watch(installedPluginsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('plugins.title')),
        actions: [
          IconButton(
            tooltip: _showReserved
                ? context.trM('plugins.hideReserved')
                : context.trM('plugins.showReserved'),
            onPressed: () => setState(() => _showReserved = !_showReserved),
            icon: Icon(_showReserved
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: context.trM('plugins.marketplace'),
            onPressed: () => context.push('/plugins/market'),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: () => ref.invalidate(installedPluginsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInstallSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.trM('plugins.install')),
      ),
      body: installed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e is ApiException ? e.message : e.toString())),
        data: (result) {
          // Web dashboard parity: reserved (built-in) plugins hidden by
          // default behind the eye toggle.
          final list = _showReserved
              ? result.plugins
              : result.plugins.where((p) => !p.reserved).toList();
          if (result.loadError != null) _showLoadError(result.loadError!);
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.trM('plugins.noInstalled'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(installedPluginsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                final subtitle = [
                  if (p.version.isNotEmpty) 'v${p.version}',
                  if (p.author.isNotEmpty) 'by ${p.author}',
                  if (p.reserved) 'built-in',
                ].join(' · ');
                return ItemCard(
                  title: p.name,
                  subtitle: subtitle.isEmpty ? p.description : subtitle,
                  icon: Icons.extension_outlined,
                  imageUrl: _logoUrl(p),
                  enabled: p.activated,
                  onEnabledChanged:
                      p.reserved ? null : (v) => _toggle(context, ref, p, v),
                  onTap: () => context.push('/plugins/detail', extra: p.raw),
                  actions: [
                    ItemCardAction(
                      icon: Icons.description_outlined,
                      label: context.trM('plugins.viewReadme'),
                      onSelected: () => context.push(
                        '/plugins/readme',
                        extra: {'name': p.name, 'repo': p.repo},
                      ),
                    ),
                    ItemCardAction(
                      icon: Icons.refresh,
                      label: context.trM('plugins.actionReload'),
                      onSelected: () => _reload(context, ref, p),
                    ),
                    ItemCardAction(
                      icon: Icons.upgrade,
                      label: context.trM('plugins.actionUpdate'),
                      onSelected: () => _update(context, ref, p),
                    ),
                    if (!p.reserved)
                      ItemCardAction(
                        icon: Icons.delete_outline,
                        label: context.trM('plugins.actionUninstall'),
                        destructive: true,
                        onSelected: () => _uninstall(context, ref, p),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showInstallSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(context.trM('plugins.installFromUrl')),
            subtitle: Text(context.trM('plugins.installFromUrlHint')),
            onTap: () {
              Navigator.pop(sheetCtx);
              _showInstallUrlDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(context.trM('plugins.installFromFile')),
            subtitle: Text(context.trM('plugins.installFromFileHint')),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await _pickAndUpload(context, ref);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
    withData: false,
  );
  final path = picked?.files.single.path;
  final name = picked?.files.single.name;
  if (path == null || name == null) return;

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final progressNotifier = ValueNotifier<double>(0);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Uploading plugin'),
      content: ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (_, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: p == 0 ? null : p),
            const SizedBox(height: 4),
            Text(p == 0 ? 'Connecting…' : '${(p * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    ),
  ));

  try {
    await ref.read(pluginServiceProvider).installFromUpload(
          filePath: path,
          fileName: name,
          onProgress: (sent, total) {
            if (total > 0) {
              progressNotifier.value = sent / total;
            }
          },
        );
    ref.invalidate(installedPluginsProvider);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(content: Text('Installed $name.')));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  } finally {
    progressNotifier.dispose();
  }
}

Future<void> _showInstallUrlDialog(
    BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController();
  bool busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Install plugin from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Git repository URL',
                hintText: 'https://github.com/owner/repo',
                border: OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final url = ctrl.text.trim();
                    if (url.isEmpty) {
                      setState(() => error = 'URL is required');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(pluginServiceProvider)
                          .installFromUrl(url);
                      ref.invalidate(installedPluginsProvider);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Plugin install started.'),
                          ),
                        );
                      }
                    } on ApiException catch (e) {
                      setState(() => error = e.message);
                    } finally {
                      setState(() => busy = false);
                    }
                  },
            child: busy
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Install'),
          ),
        ],
      ),
    ),
  );
}
