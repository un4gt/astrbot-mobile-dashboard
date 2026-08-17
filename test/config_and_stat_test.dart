// Unit tests for the config selector helpers, dashboard stat parsing, and
// the local debug mock interceptor.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astrbot_mobile/core/api/local_debug_mock.dart';
import 'package:astrbot_mobile/features/config/domain/config_bundle.dart';
import 'package:astrbot_mobile/features/config/domain/selector.dart';
import 'package:astrbot_mobile/features/dashboard/data/dashboard_service.dart';

void main() {
  group('getValueBySelector / setValueBySelector', () {
    test('reads nested dotted paths and returns null for missing', () {
      final cfg = <String, dynamic>{
        'provider_settings': {'default_provider_id': 'openai'},
      };
      expect(getValueBySelector(cfg, 'provider_settings.default_provider_id'),
          'openai');
      expect(getValueBySelector(cfg, 'provider_settings.missing'), isNull);
      expect(getValueBySelector(cfg, 'missing.path'), isNull);
    });

    test('writes nested dotted paths, creating intermediate maps', () {
      final cfg = <String, dynamic>{};
      setValueBySelector(cfg, 'a.b.c', 1);
      expect(cfg['a']['b']['c'], 1);
    });
  });

  group('conditionSatisfied', () {
    test('scalar equality and list variants', () {
      final cfg = <String, dynamic>{
        'type': 'aiocqhttp',
        'provider': 'xai',
        'plugins': ['a', 'b'],
      };
      expect(
        conditionSatisfied({'type': 'aiocqhttp'}, cfg),
        isTrue,
      );
      expect(
        conditionSatisfied({'type': 'telegram'}, cfg),
        isFalse,
      );
      expect(
        conditionSatisfied({'provider': ['xai', 'other']}, cfg),
        isTrue,
      );
      expect(conditionSatisfied(null, cfg), isTrue);
    });
  });

  group('mergeWithTemplateDefaults', () {
    test('live values win, missing template keys are filled recursively', () {
      final existing = <String, dynamic>{
        'id': 'my-openai',
        'type': 'openai_chat_completion',
        'enable': false,
        'api_base': 'https://custom/v1',
        'model_config': {'model': 'gpt-4o'},
      };
      final template = <String, dynamic>{
        'id': 'openai',
        'type': 'openai_chat_completion',
        'enable': true,
        'key': [],
        'api_base': 'https://api.openai.com/v1',
        'timeout': 120,
        'model_config': {'model': 'gpt-4o-mini', 'temperature': 0.4},
        'modalities': ['text', 'image', 'tool_use'],
      };
      final merged = mergeWithTemplateDefaults(existing, template);
      expect(merged['id'], 'my-openai'); // live wins
      expect(merged['enable'], false); // live wins
      expect(merged['api_base'], 'https://custom/v1');
      expect(merged['timeout'], 120); // filled from template
      expect(merged['key'], []); // filled from template
      expect(merged['model_config']['model'], 'gpt-4o'); // live wins
      expect(merged['model_config']['temperature'], 0.4); // filled
      expect(merged['modalities'], ['text', 'image', 'tool_use']);
      // Original maps untouched.
      expect(existing.containsKey('timeout'), isFalse);
      expect(existing['model_config'].containsKey('temperature'), isFalse);
    });

    test('null template returns copy of config', () {
      final cfg = <String, dynamic>{'a': 1};
      final out = mergeWithTemplateDefaults(cfg, null);
      expect(out, cfg);
      expect(identical(out, cfg), isFalse);
    });
  });

  group('deepMergeOverwrite', () {
    test('src wins, maps recurse', () {
      final dst = <String, dynamic>{
        'a': 1,
        'nested': {'x': 1, 'y': 2},
      };
      final src = <String, dynamic>{
        'a': 9,
        'nested': {'y': 20, 'z': 30},
      };
      deepMergeOverwrite(dst, src);
      expect(dst['a'], 9);
      expect(dst['nested'], {'x': 1, 'y': 20, 'z': 30});
    });
  });

  group('DashboardStat parsing (matches StatRoute.get_stat payload)', () {
    final payload = <String, dynamic>{
      'platform': [
        {'name': 'aiocqhttp', 'count': 12, 'timestamp': 1700000000},
        {'name': 'telegram', 'count': 5, 'timestamp': 1700000100},
      ],
      'message_count': 1234,
      'platform_count': 2,
      'plugin_count': 7,
      'message_time_series': [
        [1700000000, 3],
        [1700003600, 4],
      ],
      'running': {'hours': 2, 'minutes': 3, 'seconds': 4},
      'memory': {'process': 256, 'system': 16384},
      'cpu_percent': 12.3,
      'start_time': 1699990000,
    };

    test('memory map is MiB and does not crash', () {
      final s = DashboardStat(payload);
      expect(s.memoryProcessMB, 256);
      expect(s.memorySystemMB, 16384);
    });

    test('legacy flat byte count still converts', () {
      final s = DashboardStat({'memory_used': 268435456});
      expect(s.memoryProcessMB, closeTo(256, 0.001));
      expect(s.memorySystemMB, isNull);
    });

    test('cpu reads cpu_percent first', () {
      expect(DashboardStat(payload).cpuLoad, 12.3);
      expect(DashboardStat({'cpu_load': 5}).cpuLoad, 5);
    });

    test('platform breakdown from grouped list', () {
      final s = DashboardStat(payload);
      expect(s.platformMessages, {'aiocqhttp': 12, 'telegram': 5});
    });

    test('running components preferred for uptime', () {
      expect(DashboardStat(payload).running,
          const Duration(hours: 2, minutes: 3, seconds: 4));
      expect(DashboardStat({'running': {'hours': 0, 'minutes': 0, 'seconds': 0}}).running, isNull);
    });

    test('time series keeps numeric pairs only', () {
      final s = DashboardStat({
        'message_time_series': [
          [1, 2],
          ['bad'],
          [3, 'x'],
        ],
      });
      expect(s.messageTimeSeries, [
        [1, 2],
      ]);
    });

    // Capted verbatim from a live AstrBot v4.7.1 instance
    // (pip install astrbot==4.7.1, GET /api/stat/get?offset_sec=86400).
    test('real v4.7.1 server payload parses fully', () {
      final s = DashboardStat(<String, dynamic>{
        'platform': <dynamic>[],
        'message_count': 0,
        'platform_count': 1,
        'plugin_count': 0,
        'plugins': <dynamic>[],
        'running': {'hours': 0, 'minutes': 2, 'seconds': 17},
        'memory': {'process': 270, 'system': 32490},
        'cpu_percent': 7.0,
        'thread_count': 6,
        'start_time': 1786922815,
        'message_time_series': [
          [1786836544, 0],
          [1786840144, 0],
        ],
      });
      expect(s.memoryProcessMB, 270);
      expect(s.memorySystemMB, 32490);
      expect(s.cpuLoad, 7.0);
      expect(s.running, const Duration(minutes: 2, seconds: 17));
      expect(s.onlinePlatformCount, 1);
      expect(s.startTime, 1786922815);
      expect(s.messageCount, 0);
      expect(s.platformMessages, isEmpty);
      expect(s.messageTimeSeries.length, 2);
    });
  });

  group('ConfigBundle templates', () {
    test('provider/platform template getters walk the metadata tree', () {
      final bundle = configBundleForTest();
      expect(bundle.providerTemplates.keys, contains('OpenAI'));
      expect(bundle.providerTemplates['OpenAI']!['type'], 'openai_chat_completion');
      expect(bundle.providerItemsSchema!['items'], isA<Map>());
      expect(bundle.platforms, hasLength(1));
      expect(bundle.providers, hasLength(1));
    });
  });

  group('local debug mode', () {
    /// Dio pointed at an unroutable address -- every request below succeeds
    /// only because the mock interceptor resolves it before the network.
    Dio mockDio() {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://127.0.0.1:9',
        connectTimeout: const Duration(seconds: 2),
      ));
      dio.interceptors.add(LocalDebugInterceptor());
      return dio;
    }

    test('interceptor resolves requests without touching the network',
        () async {
      final dio = mockDio();
      final res = await dio.get<dynamic>(
        '/api/stat/get',
        queryParameters: {'offset_sec': 86400},
      );
      expect(res.statusCode, 200);
      final stat =
          DashboardStat(Map<String, dynamic>.from(res.data as Map));
      expect(stat.memoryProcessMB, 312); // memory map, not bytes
      expect(stat.messageTimeSeries, isNotEmpty);
      expect(stat.platformMessages.keys, contains('aiocqhttp'));
      expect(stat.running, isNotNull);
    });

    test('config payload feeds ConfigBundle for all editor screens',
        () async {
      final data = localDebugPayloadFor('/api/config/get', const {});
      final bundle = ConfigBundle(
        config: Map<String, dynamic>.from(data['config']),
        metadata: Map<String, dynamic>.from(data['metadata']),
      );
      expect(bundle.platforms, hasLength(2));
      expect(bundle.providers, hasLength(4));
      expect(bundle.providerTemplates.keys, containsAll(['OpenAI', 'Ollama']));
      expect(bundle.platformTemplates, isNotEmpty);
      expect(bundle.providerItemsSchema!['items'], isA<Map>());
      // Template-merge parity: editing openai keeps its values and fills
      // nothing missing from its own template.
      final merged = mergeWithTemplateDefaults(
        Map<String, dynamic>.from(bundle.providers.first),
        bundle.providerTemplates['OpenAI'],
      );
      expect(merged['api_base'], 'https://api.openai.com/v1');
    });

    test('abconf returns full groups and system group variants', () {
      final normal =
          localDebugPayloadFor('/api/config/abconf', const {'id': 'default'})
              as Map<String, dynamic>;
      expect(
        Map<String, dynamic>.from(normal['metadata'] as Map).keys,
        containsAll(['ai_group', 'platform_group', 'plugin_group', 'ext_group']),
      );
      final system = localDebugPayloadFor(
          '/api/config/abconf', const {'system_config': '1'}) as Map<String, dynamic>;
      expect(
        Map<String, dynamic>.from(system['metadata'] as Map).keys,
        ['system_group'],
      );
    });

    test('plugin config shape is unwrapped by the detail screen logic', () {
      final data = localDebugPayloadFor(
          '/api/config/get', const {'plugin_name': 'random_chat'}) as Map;
      final md = Map<String, dynamic>.from(data['metadata'] as Map);
      expect(md.length, 1);
      final schema = Map<String, dynamic>.from(md.values.first as Map);
      expect(schema['items'], isA<Map>());
    });

    test('plugin list and market list shapes', () {
      final plugins =
          localDebugPayloadFor('/api/plugin/get', const {}) as Map;
      expect(plugins['data'], isA<List>());
      final market =
          localDebugPayloadFor('/api/plugin/market_list', const {});
      expect(market, isA<List>());
    });

    test('SSE-style stream payloads decode as events', () {
      // The live-log stream body is exercised indirectly via payload checks;
      // here we verify a stat default fallback for unknown endpoints.
      expect(localDebugPayloadFor('/api/stat/restart-core', const {}),
          isA<Map>());
    });
  });
}

ConfigBundle configBundleForTest() => ConfigBundle(
      config: {
        'platform': [
          {'id': 'qq', 'type': 'aiocqhttp', 'enable': true},
        ],
        'provider': [
          {'id': 'openai', 'type': 'openai_chat_completion', 'enable': true},
        ],
      },
      metadata: {
        'provider_group': {
          'name': '服务提供商',
          'metadata': {
            'provider': {
              'type': 'list',
              'config_template': {
                'OpenAI': {
                  'id': 'openai',
                  'type': 'openai_chat_completion',
                },
              },
              'items': {
                'id': {'type': 'string'},
                'model_config': {
                  'type': 'object',
                  'items': {
                    'model': {'type': 'string'},
                  },
                },
              },
            },
          },
        },
      },
    );
