/// Diagnostic page UI -- lists each endpoint, lets the user run/expand each,
/// and exports the bundle for bug reports.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../data/diagnostic_service.dart';

class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  final Map<String, EndpointResult> _results = {};
  final Map<String, bool> _running = {};
  bool _runningAll = false;

  Future<void> _runOne(DiagnosticEndpoint e) async {
    setState(() => _running[e.path] = true);
    final res = await ref.read(diagnosticServiceProvider).probe(e);
    if (!mounted) return;
    setState(() {
      _running[e.path] = false;
      _results[e.path] = res;
    });
  }

  Future<void> _runAll() async {
    setState(() => _runningAll = true);
    for (final e in diagnosticEndpoints) {
      await _runOne(e);
    }
    if (mounted) setState(() => _runningAll = false);
  }

  Future<void> _exportAll() async {
    final list = diagnosticEndpoints
        .map((e) => _results[e.path])
        .whereType<EndpointResult>()
        .toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.trM('diagnostic.runAll'))),
      );
      return;
    }
    await ref.read(diagnosticServiceProvider).exportAndShare(list);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('diagnostic.title')),
        actions: [
          IconButton(
            tooltip: context.trM('diagnostic.runAll'),
            onPressed: _runningAll ? null : _runAll,
            icon: _runningAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
          ),
          IconButton(
            tooltip: context.trM('diagnostic.exportAll'),
            onPressed: _exportAll,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              context.trM('diagnostic.subtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          for (final e in diagnosticEndpoints)
            _EndpointTile(
              endpoint: e,
              result: _results[e.path],
              busy: _running[e.path] ?? false,
              onRun: () => _runOne(e),
            ),
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.endpoint,
    required this.result,
    required this.busy,
    required this.onRun,
  });

  final DiagnosticEndpoint endpoint;
  final EndpointResult? result;
  final bool busy;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasResult = result != null;
    final ok = result?.ok ?? false;
    final missing = result?.missingFields ?? const [];
    final hasMissing = missing.isNotEmpty;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    if (busy) {
      statusColor = cs.outline;
      statusIcon = Icons.schedule;
      statusLabel = context.trM('diagnostic.running');
    } else if (!hasResult) {
      statusColor = cs.outline;
      statusIcon = Icons.radio_button_unchecked;
      statusLabel = '-';
    } else if (ok && !hasMissing) {
      statusColor = cs.tertiary;
      statusIcon = Icons.check_circle;
      statusLabel = context.trM('diagnostic.ok');
    } else if (ok && hasMissing) {
      statusColor = const Color(0xFFFFB300); // amber
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = context.trM('diagnostic.ok');
    } else {
      statusColor = cs.error;
      statusIcon = Icons.error_outline;
      statusLabel = context.trM('diagnostic.fail');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(endpoint.label,
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          '${endpoint.method} ${endpoint.path}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasResult && result!.statusCode != null
                  ? '${result!.statusCode}'
                  : statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: busy ? null : onRun,
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
            ),
          ],
        ),
        children: [
          if (hasResult)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (endpoint.expectedFields.isNotEmpty) ...[
                    Text(context.trM('diagnostic.expectedFields'),
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final f in endpoint.expectedFields)
                          _FieldChip(name: f, missing: missing.contains(f)),
                      ],
                    ),
                    if (missing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          context.trM('diagnostic.missingFields',
                              params: {'fields': missing.join(', ')}),
                          style: TextStyle(color: cs.error, fontSize: 12),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          context.trM('diagnostic.presentFields'),
                          style: TextStyle(color: cs.tertiary, fontSize: 12),
                        ),
                      ),
                    const Divider(),
                  ],
                  Row(
                    children: [
                      Text(context.trM('diagnostic.raw'),
                          style: Theme.of(context).textTheme.labelMedium),
                      const Spacer(),
                      IconButton(
                        tooltip: context.trM('common.copy'),
                        onPressed: () {
                          final body = result!.error != null
                              ? 'ERROR: ${result!.error}\n\n${_pretty(result!.rawData)}'
                              : _pretty(result!.rawData);
                          Clipboard.setData(ClipboardData(text: body));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.trM('common.linkCopied')),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      result!.error != null
                          ? 'ERROR: ${result!.error}\n\n${_pretty(result!.rawData)}'
                          : _pretty(result!.rawData),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _pretty(dynamic data) {
    if (data == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.name, required this.missing});
  final String name;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: missing
            ? cs.error.withValues(alpha: 0.15)
            : cs.tertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            missing ? Icons.close : Icons.check,
            size: 12,
            color: missing ? cs.error : cs.tertiary,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: missing ? cs.error : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
