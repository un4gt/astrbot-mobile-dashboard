/// Minimal ANSI escape-code parser for AstrBot's log payloads.
///
/// AstrBot uses a small subset of SGR codes (ESC `[<n>;<n>m`); we map them
/// to Flutter [TextStyle] runs. Anything we don't recognize is rendered as
/// plain text. Lifted from `ConsoleDisplayer.vue` lines 28-37.
library;

import 'package:flutter/material.dart';

/// Escape sequence prefix: ASCII ESC (0x1B) + `[`.
const _esc = '[';

const _palette = <String, TextStyle>{
  // bright/bold colors
  '1;34': TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold),
  '1;36': TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.bold),
  '1;33': TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold),
  '1;31': TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold),
  '1;32': TextStyle(color: Color(0xFF43A047), fontWeight: FontWeight.bold),
  '1;35': TextStyle(color: Color(0xFFAB47BC), fontWeight: FontWeight.bold),
  // plain colors
  '31': TextStyle(color: Color(0xFFE53935)),
  '32': TextStyle(color: Color(0xFF43A047)),
  '33': TextStyle(color: Color(0xFFFFC107)),
  '34': TextStyle(color: Color(0xFF1E88E5)),
  '35': TextStyle(color: Color(0xFFAB47BC)),
  '36': TextStyle(color: Color(0xFF00BCD4)),
};

const _baseStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  color: Color(0xFFE0E0E0),
);

/// Parses [input] into a list of [TextSpan] honoring the SGR escape sequences.
List<TextSpan> parseAnsi(String input) {
  if (!input.contains(_esc)) {
    return [TextSpan(text: input, style: _baseStyle)];
  }
  final spans = <TextSpan>[];
  TextStyle current = _baseStyle;
  var i = 0;
  while (i < input.length) {
    final escIdx = input.indexOf(_esc, i);
    if (escIdx < 0) {
      spans.add(TextSpan(text: input.substring(i), style: current));
      break;
    }
    if (escIdx > i) {
      spans.add(TextSpan(text: input.substring(i, escIdx), style: current));
    }
    final mIdx = input.indexOf('m', escIdx + _esc.length);
    if (mIdx < 0) {
      spans.add(TextSpan(text: input.substring(escIdx), style: current));
      break;
    }
    final code = input.substring(escIdx + _esc.length, mIdx);
    if (code == '0' || code.isEmpty) {
      current = _baseStyle;
    } else {
      final mapped = _palette[code];
      current = mapped != null ? _baseStyle.merge(mapped) : current;
    }
    i = mIdx + 1;
  }
  return spans;
}
