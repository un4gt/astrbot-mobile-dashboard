/// Local debug mode: intercepts every Dio request and resolves it with
/// built-in mock data so the app can be explored without an AstrBot server.
///
/// The interceptor resolves with the *unwrapped* payload (not the
/// `{status, message, data}` envelope): Dio's `handler.resolve` may or may
/// not run the following response interceptors depending on version, and
/// the envelope unwrapper passes non-envelope maps through untouched either
/// way -- so the services see the payload directly in both cases.
///
/// Streaming endpoints (`/api/live-log`, `/api/chat/send`) are served with a
/// `ResponseBody` whose byte stream emits SSE-shaped chunks.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class LocalDebugInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    if (path == '/api/live-log') {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: ResponseBody(_liveLogStream(), 200),
      ));
      return;
    }
    if (path == '/api/chat/send') {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: ResponseBody(_chatReplyStream(), 200),
      ));
      return;
    }
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: localDebugPayloadFor(path, options.queryParameters),
    ));
  }
}

/// Entry point of every mocked screen payload. Falls back to an empty map
/// for unmatched endpoints (POST writes etc. only need a 200).
dynamic localDebugPayloadFor(String path, Map<String, dynamic> query) {
  switch (path) {
    case '/api/stat/version':
      return {
        'version': 'v4.0.0-local-debug',
        'dashboard_version': 'mock',
        'change_pwd_hint': false,
        'need_migration': false,
      };
    case '/api/stat/start-time':
      return {'start_time': _startTimeSec};
    case '/api/stat/get':
      return _statGet(_parseInt(query['offset_sec']) ?? 86400);
    case '/api/update/check':
      return {
        'has_new_version': false,
        'dashboard_has_new_version': false,
        'message': '本地调试模式:未检查更新',
      };
    case '/api/config/get':
      final pluginName = query['plugin_name']?.toString();
      if (pluginName != null && pluginName.isNotEmpty) {
        return _pluginConfig(pluginName);
      }
      return {'config': _config, 'metadata': _metadataV2};
    case '/api/config/abconfs':
      return {
        'info_list': [
          {'id': 'default', 'name': '默认配置', 'path': 'data/cmd_config.json'},
        ],
      };
    case '/api/config/abconf':
      final isSystem = query['system_config']?.toString() == '1';
      return {
        'config': _config,
        'metadata': isSystem ? _metadataSystem : _metadataV3,
      };
    case '/api/config/platform/list':
      return {'platforms': _config['platform']};
    case '/api/config/provider/list':
      return _config['provider'];
    case '/api/config/provider/check_one':
      return {
        'id': query['id']?.toString() ?? 'openai',
        'model': 'gpt-4o-mini',
        'type': 'openai_chat_completion',
        'name': query['id']?.toString() ?? 'openai',
        'status': 'available',
        'error': '',
      };
    case '/api/config/provider/model_list':
      return {
        'models': ['gpt-4o-mini', 'gpt-4o', 'deepseek-chat', 'llama3.1-8b'],
        'provider_id': query['provider_id']?.toString() ?? '',
      };
    case '/api/plugin/get':
      return {'data': _installedPlugins};
    case '/api/plugin/market_list':
      return _marketPlugins;
    case '/api/plugin/readme':
      return {
        'content': '# 本地调试插件\n\n'
            '这是本地调试模式的内置 README,用于在没有服务器的情况下预览插件详情页。\n\n'
            '## 功能\n\n- 演示 README 渲染\n- 演示仓库链接跳转\n',
      };
    case '/api/persona/list':
      return _personas;
    case '/api/tools/list':
      return [
        {'name': 'web_search', 'description': '联网搜索', 'mcp_server_name': 'demo-server'},
        {'name': 'kb_retrieve', 'description': '知识库检索', 'mcp_server_name': 'demo-server'},
        {'name': 'get_weather', 'description': '查询天气', 'mcp_server_name': 'local-stdio'},
      ];
    case '/api/tools/mcp/servers':
      return [
        {'name': 'demo-server', 'active': true, 'type': 'sse', 'command': '', 'url': 'http://localhost:8090/sse'},
        {'name': 'local-stdio', 'active': false, 'type': 'stdio', 'command': 'node server.js', 'url': null},
      ];
    case '/api/kb/list':
      return {'items': _kbs};
    case '/api/kb/retrieve':
      return {
        'hits': [
          {'content': 'AstrBot 是一个多平台 LLM 聊天机器人及开发框架。', 'score': 0.92},
          {'content': '本地调试模式使用内置模拟数据。', 'score': 0.71},
        ],
      };
    case '/api/conversation/list':
      return {
        'conversations': _conversations,
        'pagination': {'page': 1, 'page_size': 20, 'total': _conversations.length, 'total_pages': 1},
      };
    case '/api/conversation/detail':
      return {
        'history': jsonEncode([
          {'role': 'user', 'message': '你好'},
          {'role': 'assistant', 'message': '你好!这是本地调试模式的演示对话。'},
          {'role': 'user', 'message': '帮我总结一下 AstrBot 的功能'},
          {'role': 'assistant', 'message': 'AstrBot 支持多平台接入、插件系统、知识库和人格管理等功能。'},
        ]),
      };
    case '/api/chat/sessions':
      return _chatSessions;
    case '/api/chat/new_session':
      return {'session_id': 'mock-${DateTime.now().millisecondsSinceEpoch}'};
    case '/api/chat/get_session':
      return {
        'history': [
          {'role': 'user', 'message': '你好,介绍一下你自己'},
          {'role': 'assistant', 'message': '你好!这里是本地调试模式的演示会话,所有数据均为内置模拟数据。'},
        ],
      };
    case '/api/session/list-rule':
      return {
        'rules': [
          {
            'umo': 'aiocqhttp:GroupMessage:123456',
            'rules': {
              'session_service_config': {'custom_name': '测试群', 'enable_session': true},
            },
          },
          {
            'umo': 'telegram:FriendMessage:777',
            'rules': {
              'provider_perf_chat_completion': 'deepseek',
            },
          },
        ],
        'total': 2,
        'available_personas': ['基础助手', '猫娘'],
        'available_chat_providers': [
          {'id': 'openai'},
          {'id': 'deepseek'},
          {'id': 'local-ollama'},
        ],
        'available_stt_providers': [
          {'id': 'stt-demo'},
        ],
        'available_tts_providers': <Map<String, dynamic>>[],
        'available_plugins': [
          {'name': 'astrbot_plugin_search'},
          {'name': 'random_chat'},
        ],
        'available_kbs': [
          {'kb_id': 'docs', 'kb_name': '项目文档'},
          {'kb_id': 'faq', 'kb_name': '常见问题'},
        ],
      };
    case '/api/session/active-umos':
      return ['aiocqhttp:GroupMessage:123456', 'telegram:FriendMessage:777'];
    case '/api/log-history':
      return {'logs': _logHistory};
    case '/api/auth/login':
      return {
        'token': 'local-debug-token',
        'username': 'local-debug',
        'change_pwd_hint': false,
      };
    default:
      if (path.startsWith('/api/config/') || path.startsWith('/api/plugin/') ||
          path.startsWith('/api/persona/') || path.startsWith('/api/kb/') ||
          path.startsWith('/api/tools/') || path.startsWith('/api/session/') ||
          path.startsWith('/api/conversation/') || path.startsWith('/api/chat/') ||
          path.startsWith('/api/auth/') || path.startsWith('/api/stat/')) {
        return <String, dynamic>{};
      }
      return <String, dynamic>{};
  }
}

// ----------------------------------------------------------------------------
// Shared clock
// ----------------------------------------------------------------------------

final DateTime _bootTime = DateTime.now();
int get _startTimeSec => _bootTime.subtract(const Duration(hours: 26)).millisecondsSinceEpoch ~/ 1000;

int? _parseInt(dynamic v) =>
    v == null ? null : int.tryParse(v.toString());

// ----------------------------------------------------------------------------
// /api/stat/get
// ----------------------------------------------------------------------------

Map<String, dynamic> _statGet(int offsetSec) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final start = nowSec - offsetSec;
  final buckets = <List<int>>[];
  var i = 0;
  for (var bucketEnd = start; bucketEnd < nowSec; bucketEnd += 3600) {
    // Deterministic pseudo-random hourly counts with a mild daily shape.
    final wave = ((i * 7) % 13) + ((i % 6 == 0) ? 9 : 0) + (i % 3);
    buckets.add([bucketEnd, wave]);
    i++;
  }
  return {
    'platform': [
      {'name': 'aiocqhttp', 'count': 812, 'timestamp': nowSec - 600},
      {'name': 'telegram', 'count': 344, 'timestamp': nowSec - 1200},
      {'name': 'webchat', 'count': 97, 'timestamp': nowSec - 300},
    ],
    'message_count': 4210,
    'platform_count': 3,
    'plugin_count': _installedPlugins.length,
    'plugins': [
      for (final p in _installedPlugins)
        {'name': p['name'], 'version': p['version'], 'is_enabled': p['activated']},
    ],
    'message_time_series': buckets,
    'running': {'hours': 26, 'minutes': 13, 'seconds': 5},
    'memory': {'process': 312, 'system': 16384},
    'cpu_percent': 18.6,
    'thread_count': 42,
    'start_time': _startTimeSec,
  };
}

// ----------------------------------------------------------------------------
// Config + metadata
// ----------------------------------------------------------------------------

final Map<String, dynamic> _providerOpenai = {
  'id': 'openai',
  'provider': 'openai',
  'type': 'openai_chat_completion',
  'provider_type': 'chat_completion',
  'enable': true,
  'key': ['sk-************'],
  'api_base': 'https://api.openai.com/v1',
  'timeout': 120,
  'model_config': {'model': 'gpt-4o-mini', 'temperature': 0.4, 'max_tokens': 1024, 'top_p': 1.0},
  'custom_headers': <String, dynamic>{},
  'custom_extra_body': <String, dynamic>{},
  'modalities': ['text', 'tool_use'],
};

final Map<String, dynamic> _providerDeepseek = {
  'id': 'deepseek',
  'provider': 'deepseek',
  'type': 'openai_chat_completion',
  'provider_type': 'chat_completion',
  'enable': true,
  'key': ['sk-************'],
  'api_base': 'https://api.deepseek.com/v1',
  'timeout': 120,
  'model_config': {'model': 'deepseek-chat', 'temperature': 0.3},
  'modalities': ['text', 'tool_use'],
};

final Map<String, dynamic> _providerOllama = {
  'id': 'local-ollama',
  'provider': 'ollama',
  'type': 'openai_chat_completion',
  'provider_type': 'chat_completion',
  'enable': false,
  'key': ['ollama'],
  'api_base': 'http://localhost:11434/v1',
  'model_config': {'model': 'llama3.1-8b', 'temperature': 0.4},
};

final Map<String, dynamic> _providerStt = {
  'id': 'stt-demo',
  'type': 'openai_stt',
  'provider_type': 'speech_to_text',
  'enable': true,
  'api_key': '',
  'api_base': 'http://127.0.0.1:9997',
  'model': 'whisper-large-v3',
  'timeout': 180,
  'launch_model_if_not_running': false,
};

Map<String, dynamic> get _config => {
      'config_version': 2,
      'platform': [
        {
          'id': 'qq-bot',
          'type': 'aiocqhttp',
          'enable': true,
          'ws_reverse_host': '127.0.0.1',
          'ws_reverse_port': 8080,
          'report_self_message': false,
        },
        {
          'id': 'tg-bot',
          'type': 'telegram',
          'enable': false,
          'telegram_token': '123456:ABC-DEF',
          'telegram_proxy': '',
          'start_command': 'start',
        },
      ],
      'provider': [
        _deepClone(_providerOpenai),
        _deepClone(_providerDeepseek),
        _deepClone(_providerOllama),
        _deepClone(_providerStt),
      ],
      'provider_settings': {
        'enable': true,
        'default_provider_id': 'openai',
        'wake_prefix': ['/'],
        'web_search': false,
        'display_reasoning_text': true,
        'default_personality': '基础助手',
        'persona_pool': [],
        'prompt_prefix': '',
        'max_context_length': 0,
        'dequeue_context_length': 6,
        'streaming_response': true,
        'show_tool_use_status': false,
        'agent_runner_type': 'native',
        'max_agent_step': 8,
        'tool_call_timeout': 60,
      },
      'provider_stt_settings': {'enable': false, 'provider_id': ''},
      'provider_tts_settings': {'enable': false, 'provider_id': ''},
      'provider_ltm_settings': {
        'group_icl_enable': false,
        'group_message_max_cnt': 300,
      },
      'platform_settings': {
        'unique_session': false,
        'reply_with_mention': false,
        'reply_with_quote': false,
        'reply_prefix': '',
        'forward_threshold': 250,
        'enable_id_white_list': false,
        'id_whitelist': [],
        'rate_limit': {'time': 5, 'count': 10, 'strategy': 'discard'},
      },
      'admins_id': ['astrbot'],
      'wake_prefix': ['/'],
      'plugin_set': ['*'],
      't2i_strategy': 'remote',
      't2i_endpoint': '',
      'log_level': 'INFO',
      'timezone': 'Asia/Shanghai',
      'http_proxy': '',
      'no_proxy': [],
      'pip_install_arg': '',
      'pypi_index_url': 'https://mirrors.aliyun.com/pypi/simple/',
      'callback_api_base': '',
    };

/// CONFIG_METADATA_2-like schema for the Provider/Platform editors.
Map<String, dynamic> get _metadataV2 => {
      'provider_group': {
        'name': '服务提供商',
        'metadata': {
          'provider': {
            'type': 'list',
            'config_template': {
              'OpenAI': _deepClone(_providerOpenai),
              'DeepSeek': _deepClone(_providerDeepseek),
              'Ollama': _deepClone(_providerOllama),
            },
            'items': {
              'id': {'description': 'ID', 'type': 'string', 'hint': '提供商的唯一 ID。'},
              'type': {'type': 'string', 'invisible': true},
              'provider': {'type': 'string', 'invisible': true},
              'provider_type': {'type': 'string', 'invisible': true},
              'enable': {'description': '启用', 'type': 'bool'},
              'key': {'description': 'API Key', 'type': 'list', 'items': {'type': 'string'}, 'hint': '多个 key 将轮询使用。'},
              'api_base': {'description': 'API Base URL', 'type': 'string'},
              'api_key': {'description': 'API Key', 'type': 'string'},
              'model': {'description': '模型名称', 'type': 'string'},
              'timeout': {'description': '请求超时时间(秒)', 'type': 'int'},
              'launch_model_if_not_running': {'description': '模型未运行时自动启动', 'type': 'bool'},
              'model_config': {
                'description': '模型配置',
                'type': 'object',
                'items': {
                  'model': {'description': '模型名称', 'type': 'string'},
                  'max_tokens': {'description': '模型最大输出长度(tokens)', 'type': 'int'},
                  'temperature': {'description': '温度', 'type': 'float'},
                  'top_p': {'description': 'Top P 值', 'type': 'float'},
                },
              },
              'custom_headers': {'description': '自定义请求头', 'type': 'dict', 'items': {}},
              'custom_extra_body': {'description': '自定义请求体参数', 'type': 'dict', 'items': {}},
              'modalities': {
                'description': '模型能力',
                'type': 'list',
                'items': {'type': 'string'},
                'options': ['text', 'image', 'tool_use'],
                'labels': ['文本', '图像', '工具使用'],
                'render_type': 'checkbox',
              },
            },
          },
        },
      },
      'platform_group': {
        'name': '消息平台',
        'metadata': {
          'platform': {
            'type': 'list',
            'config_template': {
              'QQ(NapCat/OneBotv11)': {
                'id': 'aiocqhttp',
                'type': 'aiocqhttp',
                'enable': true,
                'ws_reverse_host': '127.0.0.1',
                'ws_reverse_port': 8080,
                'report_self_message': false,
              },
              'Telegram': {
                'id': 'telegram',
                'type': 'telegram',
                'enable': true,
                'telegram_token': '',
                'telegram_proxy': '',
                'start_command': 'start',
              },
            },
            'items': {
              'id': {'description': 'ID', 'type': 'string', 'hint': '平台适配器的唯一 ID。'},
              'type': {'type': 'string', 'invisible': true},
              'enable': {'description': '启用', 'type': 'bool'},
              'ws_reverse_host': {'description': 'WebSocket 反向地址', 'type': 'string'},
              'ws_reverse_port': {'description': 'WebSocket 反向端口', 'type': 'int'},
              'report_self_message': {'description': '上报自身消息', 'type': 'bool'},
              'telegram_token': {'description': 'Bot Token', 'type': 'string', 'hint': '通过 @BotFather 获取。'},
              'telegram_proxy': {'description': '代理地址', 'type': 'string'},
              'start_command': {'description': '启动命令', 'type': 'string'},
            },
          },
        },
      },
    };

/// CONFIG_METADATA_3-like group tree for the 配置 page (normal config file).
Map<String, dynamic> get _metadataV3 => {
      'ai_group': {
        'name': 'AI 配置',
        'metadata': {
          'agent_runner': {
            'description': '智能体运行器',
            'type': 'object',
            'items': {
              'provider_settings.agent_runner_type': {
                'description': '运行器类型',
                'type': 'string',
                'options': ['native', 'dify', 'coze', 'dashscope'],
                'labels': ['内置', 'Dify', 'Coze', 'DashScope'],
              },
              'provider_settings.max_agent_step': {'description': '最大步数', 'type': 'int'},
              'provider_settings.tool_call_timeout': {'description': '工具调用超时(秒)', 'type': 'int'},
            },
          },
          'ai': {
            'description': '模型',
            'type': 'object',
            'items': {
              'provider_settings.enable': {'description': '启用', 'type': 'bool'},
              'provider_settings.default_provider_id': {
                'description': '默认模型提供商',
                'type': 'string',
                '_special': 'select_provider',
                'hint': '选择默认的聊天模型提供商。',
              },
              'provider_settings.streaming_response': {'description': '流式响应', 'type': 'bool'},
              'provider_settings.display_reasoning_text': {'description': '显示思考过程', 'type': 'bool'},
              'provider_settings.max_context_length': {
                'description': '最大上下文长度',
                'type': 'int',
                'hint': '0 表示不限制。',
              },
              'provider_settings.dequeue_context_length': {'description': '丢弃上下文条数', 'type': 'int'},
              'provider_settings.wake_prefix': {'description': '唤醒前缀', 'type': 'list', 'items': {'type': 'string'}},
              'provider_stt_settings.enable': {'description': '启用语音识别', 'type': 'bool'},
              'provider_stt_settings.provider_id': {
                'description': '语音识别提供商',
                'type': 'string',
                '_special': 'select_provider_stt',
              },
              'provider_tts_settings.enable': {'description': '启用语音合成', 'type': 'bool'},
              'provider_tts_settings.provider_id': {
                'description': '语音合成提供商',
                'type': 'string',
                '_special': 'select_provider_tts',
              },
            },
          },
          'persona': {
            'description': '人格',
            'type': 'object',
            'items': {
              'provider_settings.default_personality': {
                'description': '默认人格',
                'type': 'string',
                '_special': 'select_persona',
              },
              'provider_settings.persona_pool': {
                'description': '人格池',
                'type': 'list',
                'items': {'type': 'string'},
                '_special': 'persona_pool',
              },
              'provider_settings.prompt_prefix': {'description': '提示词前缀', 'type': 'text'},
            },
          },
          'websearch': {
            'description': '联网搜索',
            'type': 'object',
            'items': {
              'provider_settings.web_search': {'description': '启用联网搜索', 'type': 'bool'},
            },
          },
        },
      },
      'platform_group': {
        'name': '平台配置',
        'metadata': {
          'general': {
            'description': '通用',
            'type': 'object',
            'items': {
              'admins_id': {'description': '管理员 ID', 'type': 'list', 'items': {'type': 'string'}},
              'wake_prefix': {'description': '唤醒前缀', 'type': 'list', 'items': {'type': 'string'}},
              'platform_settings.unique_session': {'description': '会话隔离', 'type': 'bool'},
              'platform_settings.reply_with_mention': {'description': '回复时 @用户', 'type': 'bool'},
              'platform_settings.reply_with_quote': {'description': '回复时引用消息', 'type': 'bool'},
              'platform_settings.reply_prefix': {'description': '回复前缀', 'type': 'string'},
            },
          },
          'rate_limit': {
            'description': '速率限制',
            'type': 'object',
            'items': {
              'platform_settings.rate_limit.time': {'description': '时间窗口(秒)', 'type': 'int'},
              'platform_settings.rate_limit.count': {'description': '最大消息数', 'type': 'int'},
              'platform_settings.rate_limit.strategy': {
                'description': '超限策略',
                'type': 'string',
                'options': ['discard', 'queue'],
                'labels': ['丢弃', '排队'],
              },
            },
          },
          't2i': {
            'description': '文本转图像',
            'type': 'object',
            'items': {
              't2i_strategy': {
                'description': '渲染策略',
                'type': 'string',
                'options': ['remote', 'local'],
                'labels': ['远程', '本地'],
              },
            },
          },
        },
      },
      'plugin_group': {
        'name': '插件配置',
        'metadata': {
          'plugin': {
            'description': '插件',
            'type': 'object',
            'items': {
              'plugin_set': {
                'description': '启用的插件',
                'type': 'list',
                'items': {'type': 'string'},
                '_special': 'select_plugin_set',
              },
            },
          },
        },
      },
      'ext_group': {
        'name': '扩展功能',
        'metadata': {
          'ltm': {
            'description': '群聊记忆',
            'type': 'object',
            'items': {
              'provider_ltm_settings.group_icl_enable': {'description': '启用群聊上下文学习', 'type': 'bool'},
              'provider_ltm_settings.group_message_max_cnt': {'description': '最大消息数', 'type': 'int'},
            },
          },
        },
      },
    };

Map<String, dynamic> get _metadataSystem => {
      'system_group': {
        'name': '系统配置',
        'metadata': {
          'system': {
            'description': '系统配置',
            'type': 'object',
            'items': {
              't2i_strategy': {
                'description': '文本转图像策略',
                'type': 'string',
                'options': ['remote', 'local'],
                'labels': ['远程', '本地'],
              },
              'log_level': {
                'description': '控制台日志级别',
                'type': 'string',
                'options': ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
              },
              'pip_install_arg': {'description': 'pip 安装额外参数', 'type': 'string'},
              'pypi_index_url': {'description': 'PyPI 软件仓库地址', 'type': 'string'},
              'callback_api_base': {'description': '对外可达的回调接口地址', 'type': 'string'},
              'timezone': {'description': '时区', 'type': 'string', 'hint': 'IANA 时区名称,如 Asia/Shanghai。'},
              'http_proxy': {'description': 'HTTP 代理', 'type': 'string'},
              'no_proxy': {'description': '直连地址列表', 'type': 'list', 'items': {'type': 'string'}},
            },
          },
        },
      },
    };

Map<String, dynamic> _pluginConfig(String pluginName) => {
      'config': {
        'enable': true,
        'api_key': 'mock-key',
        'max_results': 5,
      },
      'metadata': {
        pluginName: {
          'description': '$pluginName 配置',
          'type': 'object',
          'items': {
            'enable': {'description': '启用', 'type': 'bool'},
            'api_key': {'description': 'API Key', 'type': 'string'},
            'max_results': {'description': '最大结果数', 'type': 'int'},
          },
        },
      },
    };

// ----------------------------------------------------------------------------
// Lists
// ----------------------------------------------------------------------------

final List<Map<String, dynamic>> _installedPlugins = [
  {
    'name': 'astrbot',
    'version': 'v4.0.0',
    'author': 'Soulter',
    'desc': 'AstrBot 内置插件,提供基础指令与帮助。',
    'activated': true,
    'reserved': true,
    'repo': 'https://github.com/AstrBotDevs/AstrBot',
  },
  {
    'name': 'astrbot_plugin_search',
    'version': 'v1.26.0',
    'author': 'Soulter',
    'desc': '让 LLM 可以联网搜索、总结网页内容的插件。',
    'activated': true,
    'reserved': false,
    'repo': 'https://github.com/Soulter/astrbot_plugin_search',
  },
  {
    'name': 'random_chat',
    'version': 'v1.0.7',
    'author': 'Soulter',
    'desc': '随机挑选一句话让 LLM 回复,用于测试模型连接。',
    'activated': false,
    'reserved': false,
    'repo': 'https://github.com/Soulter/random_chat',
  },
  {
    'name': 'session_controller',
    'version': 'v1.1.0',
    'author': 'lxfight',
    'desc': '提供会话控制相关指令(重置、人格切换等)。',
    'activated': true,
    'reserved': false,
    'repo': 'https://github.com/lxfight/astrbot_plugin_session_controller',
  },
  {
    'name': 'looking_glass',
    'version': 'v1.4.2',
    'author': 'Soulter',
    'desc': '识图插件,让 LLM 可以理解图片内容。',
    'activated': false,
    'reserved': false,
    'repo': 'https://github.com/Soulter/looking_glass',
  },
];

final List<Map<String, dynamic>> _marketPlugins = [
  {
    'name': 'astrbot_plugin_search',
    'version': 'v1.26.0',
    'author': 'Soulter',
    'desc': '联网搜索插件,支持多种搜索引擎。',
    'repo': 'https://github.com/Soulter/astrbot_plugin_search',
    'logo': '',
    'tags': ['搜索', '工具'],
  },
  {
    'name': 'looking_glass',
    'version': 'v1.4.2',
    'author': 'Soulter',
    'desc': '多模态识图插件。',
    'repo': 'https://github.com/Soulter/looking_glass',
    'logo': '',
    'tags': ['多模态'],
  },
  {
    'name': 'astrbot_plugin_majesty',
    'version': 'v1.0.3',
    'author': 'Soulter',
    'desc': '插件市场的示例条目(本地调试数据)。',
    'repo': 'https://github.com/Soulter/astrbot_plugin_majesty',
    'logo': '',
    'tags': ['娱乐'],
  },
];

final List<Map<String, dynamic>> _personas = [
  {
    'persona_id': '基础助手',
    'system_prompt': '你是一个乐于助人的 AI 助手,回答需要简洁、准确。',
    'tools': ['web_search'],
    'begin_dialogs': [
      {'role': 'user', 'content': '你好'},
      {'role': 'bot', 'content': '你好!有什么可以帮你的吗?'},
    ],
  },
  {
    'persona_id': '猫娘',
    'system_prompt': '你是一个说话带"喵"的猫娘助手。',
    'tools': [],
    'begin_dialogs': [],
  },
  {
    'persona_id': '翻译官',
    'system_prompt': '你是一个专业翻译,在中英之间互译。',
    'tools': [],
    'begin_dialogs': [],
  },
];

final List<Map<String, dynamic>> _kbs = [
  {
    'kb_id': 'docs',
    'kb_name': '项目文档',
    'description': 'AstrBot 相关文档的知识库(本地调试数据)。',
    'emoji_icon': '📚',
    'document_count': 12,
    'chunk_count': 340,
    'embedding_provider_id': 'embedding-demo',
    'rerank_provider_id': null,
  },
  {
    'kb_id': 'faq',
    'kb_name': '常见问题',
    'description': '常见问题解答知识库。',
    'emoji_icon': '❓',
    'document_count': 4,
    'chunk_count': 51,
    'embedding_provider_id': 'embedding-demo',
    'rerank_provider_id': null,
  },
];

final List<Map<String, dynamic>> _conversations = [
  {
    'user_id': 'aiocqhttp:GroupMessage:123456',
    'cid': 'cid-1',
    'title': 'AstrBot 交流群',
    'persona_id': '基础助手',
    'platform_id': 'aiocqhttp',
    'message_type': 'GroupMessage',
    'updated_at': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
  },
  {
    'user_id': 'aiocqhttp:FriendMessage:10001',
    'cid': 'cid-2',
    'title': '私聊调试',
    'persona_id': '猫娘',
    'platform_id': 'aiocqhttp',
    'message_type': 'FriendMessage',
    'updated_at': DateTime.now().subtract(const Duration(hours: 5)).millisecondsSinceEpoch ~/ 1000,
  },
  {
    'user_id': 'telegram:FriendMessage:777',
    'cid': 'cid-3',
    'title': 'Telegram 会话',
    'persona_id': '基础助手',
    'platform_id': 'telegram',
    'message_type': 'FriendMessage',
    'updated_at': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
  },
  {
    'user_id': 'webchat:FriendMessage:local-debug',
    'cid': 'cid-4',
    'title': 'WebChat 会话',
    'persona_id': '翻译官',
    'platform_id': 'webchat',
    'message_type': 'FriendMessage',
    'updated_at': DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000,
  },
];

final List<Map<String, dynamic>> _chatSessions = [
  {
    'session_id': 'mock-sess-1',
    'display_name': '调试会话:模型测试',
    'platform_id': 'webchat',
    'is_group': 0,
    'updated_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
  },
  {
    'session_id': 'mock-sess-2',
    'display_name': '调试会话:人格切换',
    'platform_id': 'webchat',
    'is_group': 0,
    'updated_at': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
  },
];

final List<Map<String, dynamic>> _logHistory = [
  {'level': 'INFO', 'data': '[LOCAL DEBUG] 本地调试模式已启用,以下为模拟日志。'},
  {'level': 'INFO', 'data': 'astrbot.target: 消息平台适配器 aiocqhttp 已加载'},
  {'level': 'INFO', 'data': 'provider: openai (gpt-4o-mini) 连接成功'},
  {'level': 'INFO', 'data': '插件 astrbot_plugin_search 已加载 (v1.26.0)'},
  {'level': 'WARNING', 'data': 'provider local-ollama 处于禁用状态,已跳过'},
  {'level': 'INFO', 'data': 'webchat: 收到用户消息'},
  {'level': 'ERROR', 'data': 'telegram: 连接失败(mock,可忽略)'},
  {'level': 'INFO', 'data': '知识库 docs 完成 12 个文档的索引'},
];

// ----------------------------------------------------------------------------
// Streams
// ----------------------------------------------------------------------------

/// Never-completing stream that emits a mock live-log event every few
/// seconds so the console screen shows a "connected" state.
Stream<Uint8List> _liveLogStream() {
  return Stream<Uint8List>.periodic(const Duration(seconds: 5), (i) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    return _sse({
      'type': 'log',
      'level': 'INFO',
      'data': '[$t] [LOCAL DEBUG] 实时日志模拟 #$i',
    });
  });
}

/// Emits a short mock assistant reply, then closes.
Stream<Uint8List> _chatReplyStream() async* {
  const parts = ['这是', '本地调试模式', '的模拟回复。'];
  for (var i = 0; i < parts.length; i++) {
    yield _sse({
      'type': 'plain',
      'data': parts[i],
      'chain_type': 'normal',
      'streaming': i < parts.length - 1,
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
  yield _sse({'type': 'break', 'streaming': false});
}

Uint8List _sse(Map<String, dynamic> payload) =>
    Uint8List.fromList(utf8.encode('data: ${jsonEncode(payload)}\n\n'));

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

dynamic _deepClone(dynamic v) {
  if (v is Map) {
    return v.map((k, vv) => MapEntry(k.toString(), _deepClone(vv)));
  }
  if (v is List) return v.map(_deepClone).toList();
  return v;
}
