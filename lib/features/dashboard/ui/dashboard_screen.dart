/// Dashboard home -- 4 stat cards + a message-trend line chart.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/server_switcher_sheet.dart';
import '../../auth/ui/change_password_dialog.dart';
import '../../config/data/config_service.dart';
import '../data/dashboard_service.dart';

const _ranges = <int, String>{
  3600: '1h',
  86400: '24h',
  259200: '3d',
  604800: '7d',
  2592000: '30d',
};

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _bannerDismissed = false;

  Future<void> _openChangePassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (ok == true && mounted) {
      // Server invalidates token; user is bounced to login by the router.
      await ref.read(activePwdHintProvider.notifier).set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stat = ref.watch(dashboardStatProvider);
    final config = ref.watch(configBundleProvider);
    final range = ref.watch(selectedRangeProvider);
    final showPwdHint =
        !_bannerDismissed && ref.watch(activePwdHintProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.trM('dashboard.title')),
        actions: [
          // Quick server-profile switcher (multi-server support).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton.icon(
              onPressed: () => showServerSwitcher(context),
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(
                ref.watch(profilesProvider).active?.name ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          if (ref.watch(localDebugProvider))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.trM('dashboard.localDebugBadge'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: () => ref.invalidate(dashboardStatProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showPwdHint)
            MaterialBanner(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              content: Text(context.trM('dashboard.pwdHintBanner')),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _bannerDismissed = true),
                  child: Text(context.trM('dashboard.pwdHintLater')),
                ),
                FilledButton(
                  onPressed: _openChangePassword,
                  child: Text(context.trM('dashboard.pwdHintNow')),
                ),
              ],
            ),
          Expanded(
            child: stat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    e is ApiException ? e.message : e.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (s) {
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(dashboardStatProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _statRow(context, s, config),
                      const SizedBox(height: 12),
                      _rangeChips(context, ref, range),
                      const SizedBox(height: 8),
                      _messageTrendChart(context, s),
                      const SizedBox(height: 12),
                      _platformBreakdown(context, s),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(
      BuildContext context, DashboardStat s, AsyncValue config) {
    // Prefer the server's count of loaded platform instances (same as the web
    // dashboard's platform_count); fall back to counting enabled ones in the
    // config bundle while/if it is still loading.
    final platformsFromConfig = config.valueOrNull?.platforms;
    final onlinePlatformCount = platformsFromConfig != null
        ? s.raw.containsKey('platform_count')
            ? s.onlinePlatformCount
            : platformsFromConfig.where((p) => p['enable'] == true).length
        : s.onlinePlatformCount;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          icon: Icons.message_outlined,
          label: context.trM('dashboard.messages'),
          value: s.messageCount.toString(),
          delta: s.dailyIncrease != null ? '+${s.dailyIncrease}' : null,
          color: const Color(0xFF5E35B1),
        ),
        _StatCard(
          icon: Icons.smart_toy_outlined,
          label: context.trM('dashboard.platformsOnline'),
          value: onlinePlatformCount.toString(),
          color: const Color(0xFF1E88E5),
        ),
        _StatCard(
          icon: Icons.timer_outlined,
          label: context.trM('dashboard.uptime'),
          value: _formatUptime(s.running ??
              (s.startTime != null
                  ? DateTime.now()
                      .difference(DateTime.fromMillisecondsSinceEpoch(
                          s.startTime! * 1000))
                  : null)),
          color: const Color(0xFF43A047),
        ),
        _StatCard(
          icon: Icons.memory,
          label: context.trM('dashboard.memory'),
          value: s.memoryProcessMB != null
              ? '${s.memoryProcessMB!.toStringAsFixed(0)} MB'
              : '-',
          sub: s.memorySystemMB != null
              ? '/ ${_fmtTotalMemory(s.memorySystemMB!)}'
              : null,
          delta: s.cpuLoad != null ? '${s.cpuLoad!.toStringAsFixed(1)}% CPU' : null,
          color: const Color(0xFF00ACC1),
        ),
      ],
    );
  }

  Widget _rangeChips(BuildContext context, WidgetRef ref, int range) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final entry in _ranges.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == range,
                onSelected: (sel) {
                  if (sel) {
                    ref.read(selectedRangeProvider.notifier).state = entry.key;
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageTrendChart(BuildContext context, DashboardStat s) {
    final series = s.messageTimeSeries;
    final cs = Theme.of(context).colorScheme;

    if (series.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            context.trM('dashboard.noTrendData'),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final spots = [
      for (final p in series) FlSpot(p[0].toDouble() * 1000, p[1].toDouble()),
    ];
    final maxY =
        spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);
    // Integer-only steps avoid the "0 0 1 1" duplicate labels that appear
    // when fractional intervals (e.g. maxY=1 -> 0.25) get rounded for display.
    final yInterval = math.max(1.0, (maxY / 4).ceilToDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.trM('dashboard.messageTrend'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: yInterval,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: cs.primary,
                      barWidth: 2,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformBreakdown(BuildContext context, DashboardStat s) {
    final m = s.platformMessages;
    if (m.isEmpty) return const SizedBox.shrink();
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.trM('dashboard.perPlatform'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key)),
                    Text(
                      e.value.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatUptime(Duration? dur) {
    if (dur == null) return '-';
    if (dur.inDays > 0) return '${dur.inDays}d ${dur.inHours % 24}h';
    if (dur.inHours > 0) return '${dur.inHours}h ${dur.inMinutes % 60}m';
    if (dur.inMinutes > 0) return '${dur.inMinutes}m';
    return '${dur.inSeconds}s';
  }

  /// Total system RAM reads better in GB once it crosses 1 GiB.
  String _fmtTotalMemory(num mb) => mb >= 1024
      ? '${(mb / 1024).toStringAsFixed(1)} GB'
      : '${mb.toStringAsFixed(0)} MB';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
    this.sub,
    this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? delta;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: c.withValues(alpha: 0.15),
                  child: Icon(icon, size: 16, color: c),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (sub != null || delta != null)
              Row(
                children: [
                  if (sub != null)
                    Flexible(
                      child: Text(
                        sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ),
                  if (sub != null && delta != null) const SizedBox(width: 6),
                  if (delta != null)
                    Text(
                      delta!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c,
                          ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
