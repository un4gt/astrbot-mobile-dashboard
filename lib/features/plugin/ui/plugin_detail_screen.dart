/// Plugin detail screen -- shows description, repo link, and a config
/// editor that uses ConfigForm against the schema returned by
/// `/api/config/get?plugin_name=<n>`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../config/ui/config_form.dart';
import '../data/plugin_service.dart';

class PluginDetailScreen extends ConsumerStatefulWidget {
  const PluginDetailScreen({super.key, required this.raw});
  final Map<String, dynamic> raw;

  @override
  ConsumerState<PluginDetailScreen> createState() => _PluginDetailScreenState();
}

class _PluginDetailScreenState extends ConsumerState<PluginDetailScreen> {
  final _formKey = GlobalKey<ConfigFormState>();
  late Future<Map<String, dynamic>?> _configFuture;
  bool _saving = false;

  String get _name => (widget.raw['name'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _configFuture =
        ref.read(pluginServiceProvider).getPluginConfig(_name);
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;
    final next = form.currentValue();
    setState(() => _saving = true);
    try {
      await ref.read(pluginServiceProvider).savePluginConfig(_name, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plugin config saved.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = InstalledPlugin(widget.raw);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: 'README',
            onPressed: () => context.push(
              '/plugins/readme',
              extra: {'name': p.name, 'repo': p.repo},
            ),
            icon: const Icon(Icons.description_outlined),
          ),
          if (p.repo != null && p.repo!.isNotEmpty)
            IconButton(
              tooltip: 'Open repo',
              onPressed: () => launchUrl(Uri.parse(p.repo!)),
              icon: const Icon(Icons.open_in_new),
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (p.description.isNotEmpty) ...[
            Text(p.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (p.version.isNotEmpty) Chip(label: Text('v${p.version}')),
              if (p.author.isNotEmpty) Chip(label: Text(p.author)),
              if (p.reserved) const Chip(label: Text('built-in')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>?>(
            future: _configFuture,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load config: ${snap.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }
              final data = snap.data;
              if (data == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No editable config for this plugin.'),
                );
              }
              // Server returns {config, metadata} where metadata is wrapped
              // as {<plugin_name>: {type: 'object', items: {...}}} -- the
              // web dashboard passes metadataKey=<plugin_name> to the form.
              // Unwrap that single-entry namespace here.
              Map<String, dynamic>? config;
              Map<String, dynamic>? schema;
              if (data['config'] is Map && data['metadata'] is Map) {
                config = Map<String, dynamic>.from(data['config'] as Map);
                final md = Map<String, dynamic>.from(data['metadata'] as Map);
                if (md.length == 1 && md.values.first is Map) {
                  schema =
                      Map<String, dynamic>.from(md.values.first as Map);
                }
              }
              if (config == null || schema == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Plugin returned an unrecognized schema shape.'),
                );
              }
              return ConfigForm(
                key: _formKey,
                sectionMeta: schema,
                initial: config,
                mode: ConfigFormMode.configKeys,
              );
            },
          ),
        ],
      ),
    );
  }
}
