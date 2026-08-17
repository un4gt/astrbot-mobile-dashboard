/// Platform list -- mirrors `views/PlatformPage.vue`. Cards show id, type
/// and an enable/disable switch. Tap to edit, popup menu for delete.
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
import '../data/platform_service.dart';

class PlatformListScreen extends ConsumerWidget {
  const PlatformListScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref,
      Map<String, dynamic> platform, bool enable) async {
    final updated = Map<String, dynamic>.from(platform)..['enable'] = enable;
    try {
      await ref
          .read(platformServiceProvider)
          .update((platform['id'] ?? '').toString(), updated);
      ref.invalidate(configBundleProvider);
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message, error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref,
      Map<String, dynamic> platform) async {
    final id = (platform['id'] ?? '').toString();
    final ok = await showConfirmDialog(
      context: context,
      title: context.trM('platforms.deleteTitle'),
      message: context.trM('platforms.deleteMessage', params: {'id': id}),
      destructive: true,
      confirmLabel: context.trM('common.delete'),
      cancelLabel: context.trM('common.cancel'),
    );
    if (!ok) return;
    try {
      await ref.read(platformServiceProvider).delete(id);
      ref.invalidate(configBundleProvider);
      if (context.mounted) {
        _snack(context, context.trM('platforms.deleted', params: {'id': id}));
      }
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message, error: true);
    }
  }

  void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(configBundleProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('platforms.title')),
        actions: [
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: () => ref.invalidate(configBundleProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: bundle.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/platforms/new'),
              icon: const Icon(Icons.add),
              label: Text(context.trM('platforms.add')),
            )
          : null,
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e is ApiException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(configBundleProvider),
        ),
        data: (b) {
          if (b.platforms.isEmpty) {
            return _EmptyView(
              icon: Icons.smart_toy_outlined,
              title: context.trM('platforms.empty'),
              hint: context.trM('platforms.emptyHint'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(configBundleProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: b.platforms.length,
              itemBuilder: (_, i) {
                final p = b.platforms[i];
                final type = (p['type'] ?? '').toString();
                final id = (p['id'] ?? '').toString();
                return ItemCard(
                  title: id.isEmpty ? '(no id)' : id,
                  subtitle: type,
                  icon: platformIconFor(type),
                  enabled: p['enable'] == true,
                  onEnabledChanged: (v) => _toggle(context, ref, p, v),
                  onTap: () => context.push('/platforms/edit', extra: p),
                  actions: [
                    ItemCardAction(
                      icon: Icons.edit_outlined,
                      label: context.trM('common.edit'),
                      onSelected: () =>
                          context.push('/platforms/edit', extra: p),
                    ),
                    ItemCardAction(
                      icon: Icons.delete_outline,
                      label: context.trM('common.delete'),
                      destructive: true,
                      onSelected: () => _delete(context, ref, p),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.hint,
  });
  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              context.trM('platforms.errorLoad'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.trM('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}
