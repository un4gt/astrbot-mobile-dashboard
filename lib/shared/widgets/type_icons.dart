/// Lookup tables for platform / provider icons. Minimal subset -- the Vue
/// dashboard uses image assets; we map known types to Material icons.
/// Anything unknown falls through to a generic icon.
library;

import 'package:flutter/material.dart';

const _platformIcons = <String, IconData>{
  'aiocqhttp': Icons.chat_bubble_outline,
  'qq_official': Icons.chat,
  'qq_official_webhook': Icons.chat,
  'wechatpadpro': Icons.message_outlined,
  'gewechat': Icons.message_outlined,
  'wecom': Icons.work_outline,
  'lark': Icons.flight,
  'dingtalk': Icons.business,
  'telegram': Icons.send,
  'discord': Icons.forum_outlined,
  'slack': Icons.tag,
  'kook': Icons.headset_mic,
  'misskey': Icons.cloud_outlined,
  'satori': Icons.satellite_alt,
  'vocechat': Icons.record_voice_over,
  'webchat': Icons.web,
};

const _providerIcons = <String, IconData>{
  'openai': Icons.smart_toy_outlined,
  'anthropic': Icons.psychology_outlined,
  'google': Icons.bubble_chart_outlined,
  'googlegenai': Icons.bubble_chart_outlined,
  'zhipu': Icons.auto_awesome_outlined,
  'dify': Icons.api,
  'coze': Icons.api,
  'dashscope': Icons.cloud_outlined,
  'edge_tts': Icons.record_voice_over,
  'azure': Icons.cloud_queue,
  'fishaudio': Icons.graphic_eq,
  'gsvi': Icons.graphic_eq,
  'minimax': Icons.graphic_eq,
  'volcengine': Icons.graphic_eq,
  'whisper': Icons.mic,
  'sensevoice': Icons.mic,
};

IconData platformIconFor(String? key) {
  if (key == null) return Icons.smart_toy_outlined;
  return _platformIcons[key] ?? Icons.smart_toy_outlined;
}

IconData providerIconFor(String? key) {
  if (key == null) return Icons.psychology_outlined;
  return _providerIcons[key] ?? Icons.psychology_outlined;
}
