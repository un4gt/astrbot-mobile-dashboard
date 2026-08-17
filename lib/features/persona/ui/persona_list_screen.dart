/// Persona list -- card per persona with system prompt preview and tool count.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/item_card.dart';
import '../data/persona_service.dart';

class PersonaListScreen extends ConsumerWidget {
  const PersonaListScreen({super.key});

  Future<void> _delete(BuildContext ctx, WidgetRef ref, Persona p) async {
    final ok = await showConfirmDialog(
      context: ctx,
      title: 'Delete persona?',
      message: 'Persona "${p.id}" will be removed.',
      destructive: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(personaServiceProvider).delete(p.id);
      ref.invalidate(personasProvider);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final personas = ref.watch(personasProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Persona'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(personasProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/persona/edit'),
        icon: const Icon(Icons.add),
        label: const Text('New persona'),
      ),
      body: personas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e is ApiException ? e.message : e.toString())),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No personas yet.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(personasProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                final preview = p.systemPrompt.isEmpty
                    ? '(empty system prompt)'
                    : p.systemPrompt.length > 80
                        ? '${p.systemPrompt.substring(0, 80)}…'
                        : p.systemPrompt;
                return ItemCard(
                  title: p.id,
                  subtitle: '$preview\n${p.tools.length} tool(s)',
                  icon: Icons.face_outlined,
                  onTap: () =>
                      context.push('/more/persona/view', extra: p.raw),
                  actions: [
                    ItemCardAction(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onSelected: () =>
                          context.push('/more/persona/edit', extra: p.raw),
                    ),
                    ItemCardAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
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
