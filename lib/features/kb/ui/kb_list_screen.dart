/// Knowledge Base list. Read-mostly view of `/api/kb/list` with delete and a
/// simple retrieval test sheet. Document upload + chunk editing remain on
/// the web dashboard for now (file picker / multipart upload deferred).
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/item_card.dart';
import '../data/kb_service.dart';

class KbListScreen extends ConsumerWidget {
  const KbListScreen({super.key});

  Future<void> _delete(BuildContext ctx, WidgetRef ref, KnowledgeBase kb) async {
    final ok = await showConfirmDialog(
      context: ctx,
      title: ctx.trM('kb.deleteTitle'),
      message: ctx.trM('kb.deleteMessage', params: {'name': kb.name}),
      destructive: true,
      confirmLabel: ctx.trM('common.delete'),
    );
    if (!ok) return;
    try {
      await ref.read(kbServiceProvider).delete(kb.id);
      ref.invalidate(kbListProvider);
    } on ApiException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _retrievalTest(
      BuildContext ctx, WidgetRef ref, KnowledgeBase kb) async {
    final qCtrl = TextEditingController();
    List<RetrievalHit> hits = [];
    bool busy = false;
    String? error;

    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sheetCtx.trM('kb.retrievalTestTitle', params: {'name': kb.name}),
                        style: Theme.of(sheetCtx).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Query',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final q = qCtrl.text.trim();
                                  if (q.isEmpty) return;
                                  setState(() {
                                    busy = true;
                                    error = null;
                                  });
                                  try {
                                    hits = await ref
                                        .read(kbServiceProvider)
                                        .retrieve(kbId: kb.id, query: q);
                                  } on ApiException catch (e) {
                                    error = e.message;
                                  } finally {
                                    setState(() => busy = false);
                                  }
                                },
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(sheetCtx.trM('kb.search')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(sheetCtx).colorScheme.error)),
                    Expanded(
                      child: hits.isEmpty
                          ? Center(
                              child: Text(
                                busy ? sheetCtx.trM('kb.searching') : sheetCtx.trM('kb.noResults'),
                                style: TextStyle(
                                    color: Theme.of(sheetCtx)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              itemCount: hits.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final h = hits[i];
                                return ListTile(
                                  title: Text(h.content,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: Text(h.score.toStringAsFixed(3)),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(kbListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('kb.title')),
        actions: [
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: () => ref.invalidate(kbListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e is ApiException ? e.message : e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No knowledge bases.\nCreate one from the web dashboard, then return here to browse and test retrieval.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(kbListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final kb = items[i];
                final docs = kb.documentCount;
                final chunks = kb.chunkCount;
                final providerSummary = [
                  if (kb.embeddingProviderId != null)
                    'embed: ${kb.embeddingProviderId}',
                  if (kb.rerankProviderId != null) 'rerank: ${kb.rerankProviderId}',
                ].join(' · ');
                return ItemCard(
                  title: '${kb.emojiIcon}  ${kb.name}',
                  subtitle: [
                    if (kb.description.isNotEmpty) kb.description,
                    '$docs doc(s) · $chunks chunk(s)',
                    if (providerSummary.isNotEmpty) providerSummary,
                  ].join('\n'),
                  icon: Icons.menu_book_outlined,
                  onTap: () => _retrievalTest(context, ref, kb),
                  actions: [
                    ItemCardAction(
                      icon: Icons.search,
                      label: context.trM('kb.testRetrieval'),
                      onSelected: () => _retrievalTest(context, ref, kb),
                    ),
                    ItemCardAction(
                      icon: Icons.delete_outline,
                      label: context.trM('common.delete'),
                      destructive: true,
                      onSelected: () => _delete(context, ref, kb),
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
