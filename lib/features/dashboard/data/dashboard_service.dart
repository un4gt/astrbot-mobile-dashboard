/// Stats endpoint -- single GET that returns the whole dashboard payload
/// including per-time-range message_time_series.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class DashboardStat {
  final Map<String, dynamic> raw;
  DashboardStat(this.raw);

  num get messageCount => (raw['message_count'] as num?) ?? 0;
  num? get dailyIncrease => raw['daily_increase'] as num?;

  /// v4.7.1 only sends `platform_count` (loaded platform instances); there is
  /// no separate "online" count server-side.
  num get onlinePlatformCount => (raw['platform_count'] as num?) ?? 0;
  num? get pluginCount => raw['plugin_count'] as num?;
  num? get providerCount => raw['provider_count'] as num?;

  /// `memory` is `{"process": <MiB>, "system": <MiB>}` (see StatRoute.get_stat:
  /// rss >> 20 / virtual_memory().total >> 20). Older/custom builds may send a
  /// flat byte count under `memory_used` -- only divide that legacy variant.
  num? get memoryProcessMB {
    final m = raw['memory'];
    if (m is Map) return (m['process'] as num?)?.toDouble();
    final used = raw['memory_used'];
    if (used is num) return used.toDouble() / 1024 / 1024;
    return null;
  }

  num? get memorySystemMB {
    final m = raw['memory'];
    if (m is Map) return (m['system'] as num?)?.toDouble();
    return null;
  }

  double? get cpuLoad => ((raw['cpu_percent'] ?? raw['cpu_load']) as num?)
      ?.toDouble();
  int? get startTime =>
      (raw['start_time'] as num?)?.toInt(); // seconds since epoch

  /// Server-computed uptime components `{"hours", "minutes", "seconds"}`.
  /// Preferred over recomputing from [startTime] because the two come from
  /// different clocks on the server.
  Duration? get running {
    final r = raw['running'];
    if (r is! Map) return null;
    final h = (r['hours'] as num?)?.toInt() ?? 0;
    final m = (r['minutes'] as num?)?.toInt() ?? 0;
    final s = (r['seconds'] as num?)?.toInt() ?? 0;
    if (h == 0 && m == 0 && s == 0) return null;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  /// `[[timestamp_seconds, count], ...]`. Always returns a list.
  List<List<num>> get messageTimeSeries {
    final raw = this.raw['message_time_series'];
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .where((p) => p.length >= 2 && p[0] is num && p[1] is num)
        .map((p) => [p[0] as num, p[1] as num])
        .toList();
  }

  /// Per-platform message totals in the window. The server groups them as
  /// `platform: [{"name": <id>, "count": n, "timestamp": t}, ...]`; some older
  /// builds returned a plain map instead -- support both.
  Map<String, num> get platformMessages {
    final src = raw['platform'];
    if (src is List) {
      final out = <String, num>{};
      for (final e in src) {
        if (e is Map && e['name'] != null) {
          final count = e['count'];
          out[e['name'].toString()] =
              count is num ? count : num.tryParse(count.toString()) ?? 0;
        }
      }
      return out;
    }
    final legacy = raw['platform_message_count'] ?? raw['platform_message'];
    if (legacy is Map) {
      return legacy.map(
          (k, v) => MapEntry(k.toString(), v is num ? v : num.tryParse(v.toString()) ?? 0));
    }
    return const {};
  }
}

class DashboardService {
  DashboardService(this._dio);
  final Dio _dio;

  Future<DashboardStat> getStat({int offsetSec = 86400}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/stat/get',
        queryParameters: {'offset_sec': offsetSec},
      );
      final data = res.data;
      return DashboardStat(data is Map ? Map<String, dynamic>.from(data) : {});
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final dashboardServiceProvider =
    Provider<DashboardService>((ref) => DashboardService(ref.watch(apiClientProvider)));

final selectedRangeProvider = StateProvider<int>((_) => 86400); // 24h default

final dashboardStatProvider =
    FutureProvider.autoDispose<DashboardStat>((ref) async {
  final range = ref.watch(selectedRangeProvider);
  return ref.watch(dashboardServiceProvider).getStat(offsetSec: range);
});
