/// MCP server list + tool list (function tools).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/item_card.dart';
import '../../persona/data/persona_service.dart';
import '../data/mcp_service.dart';

class ToolUseScreen extends ConsumerStatefulWidget {
  const ToolUseScreen({super.key});

  @override
  ConsumerState<ToolUseScreen> createState() => _ToolUseScreenState();
}

class _ToolUseScreenState extends ConsumerState<ToolUseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(McpServer s) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete MCP server?',
      message: '"${s.name}" will be removed.',
      destructive: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(mcpServiceProvider).deleteServer(s.name);
      ref.invalidate(mcpServersProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleTool(FunctionTool t, bool active) async {
    try {
      await ref.read(mcpServiceProvider).toggleTool(t.name, active);
      ref.invalidate(functionToolsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(mcpServersProvider);
    final tools = ref.watch(functionToolsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP / Tools'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Servers'),
            Tab(text: 'Tools'),
          ],
        ),
      ),
      floatingActionButton: _tabCtrl.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showServerDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add server'),
            )
          : null,
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildServers(servers),
          _buildTools(tools),
        ],
      ),
    );
  }

  Widget _buildServers(AsyncValue<List<McpServer>> data) {
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(e is ApiException ? e.message : e.toString())),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No MCP servers yet.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(mcpServersProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];
              final subtitle = [
                s.type,
                if (s.command != null) s.command!,
                if (s.url != null) s.url!,
              ].where((v) => v.isNotEmpty).join(' · ');
              return ItemCard(
                title: s.name,
                subtitle: subtitle,
                icon: Icons.dns_outlined,
                enabled: s.active,
                onEnabledChanged: (v) async {
                  final updated = Map<String, dynamic>.from(s.raw);
                  updated['active'] = v;
                  try {
                    await ref.read(mcpServiceProvider).updateServer(updated);
                    ref.invalidate(mcpServersProvider);
                  } on ApiException catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  }
                },
                onTap: () => _showServerDialog(initial: s.raw),
                actions: [
                  ItemCardAction(
                    icon: Icons.network_check,
                    label: 'Test',
                    onSelected: () async {
                      try {
                        await ref.read(mcpServiceProvider).testServer(s.raw);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Test OK for ${s.name}')),
                          );
                        }
                      } on ApiException catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
                      }
                    },
                  ),
                  ItemCardAction(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    destructive: true,
                    onSelected: () => _delete(s),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTools(AsyncValue<List<FunctionTool>> data) {
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(e is ApiException ? e.message : e.toString())),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tools registered.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(functionToolsProvider),
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = list[i];
              return SwitchListTile(
                title: Text(t.name),
                subtitle: Text([
                  if (t.mcpServerName != null) t.mcpServerName!,
                  if (t.description != null) t.description!,
                ].where((s) => s.isNotEmpty).join(' · ')),
                // Server returns no per-tool active state in the list; we
                // flip via the toggle endpoint and let the server settle.
                value: true,
                onChanged: (v) => _toggleTool(t, v),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showServerDialog({Map<String, dynamic>? initial}) async {
    final isEdit = initial != null;
    final ctrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        initial ??
            <String, dynamic>{
              'name': '',
              'type': 'stdio',
              'command': 'npx',
              'args': <String>[],
              'env': <String, String>{},
            },
      ),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit MCP server' : 'Add MCP server'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final raw = ctrl.text;
              try {
                final parsed = jsonDecode(raw) as Map<String, dynamic>;
                Navigator.pop(ctx);
                final svc = ref.read(mcpServiceProvider);
                if (isEdit) {
                  await svc.updateServer(parsed);
                } else {
                  await svc.addServer(parsed);
                }
                ref.invalidate(mcpServersProvider);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Invalid JSON: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
