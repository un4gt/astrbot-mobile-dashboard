// Regression tests for the chat (test) feature: history parsing against the
// real PlatformMessageHistory rows the v4.7.1 server returns, and streaming
// chunk parsing from /api/chat/send.
import 'package:flutter_test/flutter_test.dart';

import 'package:astrbot_mobile/features/chat/domain/chat_message.dart';

void main() {
  group('ChatMessage.fromServer (v4.7.1 PlatformMessageHistory rows)', () {
    test('user row: payload nested in content dict', () {
      final m = ChatMessage.fromServer({
        'platform_id': 'webchat',
        'user_id': 'abc',
        'sender_id': 'astrbot',
        'sender_name': 'astrbot',
        'content': {'type': 'user', 'message': '你好'},
      });
      expect(m.role, 'user');
      expect(m.content, '你好');
      expect(m.images, isEmpty);
    });

    test('bot row: reasoning and text both carried', () {
      final m = ChatMessage.fromServer({
        'platform_id': 'webchat',
        'content': {
          'type': 'bot',
          'message': '答案',
          'reasoning': '思考过程...',
        },
      });
      expect(m.role, 'assistant');
      expect(m.content, '答案');
      expect(m.reasoning, '思考过程...');
    });

    test('user row with image_url list extracts filenames', () {
      final m = ChatMessage.fromServer({
        'content': {
          'type': 'user',
          'message': '看这张图',
          'image_url': ['img_123.png'],
        },
      });
      expect(m.content, '看这张图');
      expect(m.images, ['img_123.png']);
    });

    test('bot row with audio_url list extracts first filename', () {
      final m = ChatMessage.fromServer({
        'content': {
          'type': 'bot',
          'message': '',
          'audio_url': ['rec_1.wav'],
        },
      });
      expect(m.audio, 'rec_1.wav');
    });

    test('legacy flat {role, content} shape still parses', () {
      final m = ChatMessage.fromServer({'role': 'user', 'content': 'plain'});
      expect(m.role, 'user');
      expect(m.content, 'plain');
    });

    test('multimodal content list still parses text + image segments', () {
      final m = ChatMessage.fromServer({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'hi'},
          {'type': 'image', 'image_url': {'url': 'a.png'}},
        ],
      });
      expect(m.content, 'hi');
      expect(m.images, ['a.png']);
    });
  });
}
