/// Live log viewer. Streams `/api/live-log` via [logStreamProvider], renders
/// most-recent-at-bottom with optional auto-scroll and level filter chips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/utils/ansi_parser.dart';
import '../application/log_stream_controller.dart';

const _allLevels = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'];

const _levelColors = <String, Color>{
  'DEBUG': Color(0xFF9E9E9E),
  'INFO': Color(0xFF42A5F5),
  'WARNING': Color(0xFFFFB300),
  'ERROR': Color(0xFFE53935),
  'CRITICAL': Color(0xFFAB47BC),
};

class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});

  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  final _scroll = ScrollController();
  final Set<String> _levels = {..._allLevels};
  bool _autoScroll = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeScroll() {
    if (!_autoScroll) return;
    // Must defer: during the build that first mounts the ListView the
    // controller has no clients yet, so hasClients/maxScrollExtent can only
    // be trusted after the frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(logStreamProvider);
    // Trigger scroll after each rebuild that adds entries.
    _maybeScroll();
    final filtered =
        stream.entries.where((e) => _levels.contains(e.level.toUpperCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('console.title')),
        actions: [
          IconButton(
            tooltip: context.trM('console.reconnect'),
            onPressed: () => ref.read(logStreamProvider.notifier).reconnect(),
            icon: const Icon(Icons.cable),
          ),
          IconButton(
            tooltip: context.trM('console.clear'),
            onPressed: () => ref.read(logStreamProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusBar(connected: stream.connected, error: stream.error),
          _LevelFilter(
            selected: _levels,
            onChanged: (next) => setState(() {
              _levels
                ..clear()
                ..addAll(next);
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Spacer(),
                Text(context.trM('console.autoScroll')),
                Switch(
                  value: _autoScroll,
                  onChanged: (v) => setState(() => _autoScroll = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        context.trM('console.waiting'),
                        style: const TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    )
                  : Scrollbar(
                      controller: _scroll,
                      child: ListView.builder(
                        controller: _scroll,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _LogLine(entry: filtered[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.connected, this.error});
  final bool connected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = connected ? cs.tertiary : cs.error;
    final icon = connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;
    final label = connected
        ? context.trM('console.connected')
        : (error != null
            ? context.trM('console.reconnectingError', params: {'error': error!})
            : context.trM('console.reconnecting'));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelFilter extends StatelessWidget {
  const _LevelFilter({required this.selected, required this.onChanged});
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final lv in _allLevels)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
              child: FilterChip(
                label: Text(lv),
                selected: selected.contains(lv),
                selectedColor: _levelColors[lv]?.withValues(alpha: 0.2),
                checkmarkColor: _levelColors[lv],
                onSelected: (on) {
                  final next = {...selected};
                  on ? next.add(lv) : next.remove(lv);
                  onChanged(next);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final spans = parseAnsi(entry.data);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText.rich(
        TextSpan(children: spans),
      ),
    );
  }
}
