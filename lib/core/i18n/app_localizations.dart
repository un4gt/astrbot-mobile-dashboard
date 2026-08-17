/// Loads the AstrBot dashboard JSON locales (verbatim copy of
/// `dashboard/src/i18n/locales/{en-US,zh-CN}/...`) into a nested tree
/// and resolves dotted keys via [t].
///
/// Tree shape mirrors `translations.ts`:
///   core.{common, actions, status, navigation, header, shared}
///   features.{chat, extension, conversation, session-management, tooluse,
///             provider, platform, config, config-metadata, console, about,
///             settings, auth, chart, dashboard, persona, migration}
///   features.alkaid.{index, knowledge-base, memory}
///   features.knowledge-base.{index, detail, document}
///   messages.{errors, success, validation}
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations._(this.locale, this._tree);

  final Locale locale;
  final Map<String, dynamic> _tree;

  static const supportedLocales = <Locale>[
    Locale('en', 'US'),
    Locale('zh', 'CN'),
  ];

  /// Returns the IETF tag we use for asset paths: 'en-US' / 'zh-CN'.
  static String _tagOf(Locale locale) {
    if (locale.languageCode == 'zh') return 'zh-CN';
    return 'en-US';
  }

  static const _modules = <_ModSpec>[
    // core/*
    _ModSpec(['core', 'common'], 'core/common.json'),
    _ModSpec(['core', 'actions'], 'core/actions.json'),
    _ModSpec(['core', 'status'], 'core/status.json'),
    _ModSpec(['core', 'navigation'], 'core/navigation.json'),
    _ModSpec(['core', 'header'], 'core/header.json'),
    _ModSpec(['core', 'shared'], 'core/shared.json'),
    // features/*
    _ModSpec(['features', 'chat'], 'features/chat.json'),
    _ModSpec(['features', 'extension'], 'features/extension.json'),
    _ModSpec(['features', 'conversation'], 'features/conversation.json'),
    _ModSpec(
        ['features', 'session-management'], 'features/session-management.json'),
    // NOTE: dashboard mounts tool-use.json at features.tooluse (no hyphen).
    _ModSpec(['features', 'tooluse'], 'features/tool-use.json'),
    _ModSpec(['features', 'provider'], 'features/provider.json'),
    _ModSpec(['features', 'platform'], 'features/platform.json'),
    _ModSpec(['features', 'config'], 'features/config.json'),
    _ModSpec(['features', 'config-metadata'], 'features/config-metadata.json'),
    _ModSpec(['features', 'console'], 'features/console.json'),
    _ModSpec(['features', 'about'], 'features/about.json'),
    _ModSpec(['features', 'settings'], 'features/settings.json'),
    _ModSpec(['features', 'auth'], 'features/auth.json'),
    _ModSpec(['features', 'chart'], 'features/chart.json'),
    _ModSpec(['features', 'dashboard'], 'features/dashboard.json'),
    _ModSpec(['features', 'persona'], 'features/persona.json'),
    _ModSpec(['features', 'migration'], 'features/migration.json'),
    _ModSpec(['features', 'mobile'], 'features/mobile.json'),
    _ModSpec(['features', 'alkaid', 'index'], 'features/alkaid/index.json'),
    _ModSpec(['features', 'alkaid', 'knowledge-base'],
        'features/alkaid/knowledge-base.json'),
    _ModSpec(['features', 'alkaid', 'memory'], 'features/alkaid/memory.json'),
    _ModSpec(['features', 'knowledge-base', 'index'],
        'features/knowledge-base/index.json'),
    _ModSpec(['features', 'knowledge-base', 'detail'],
        'features/knowledge-base/detail.json'),
    _ModSpec(['features', 'knowledge-base', 'document'],
        'features/knowledge-base/document.json'),
    // messages/*
    _ModSpec(['messages', 'errors'], 'messages/errors.json'),
    _ModSpec(['messages', 'success'], 'messages/success.json'),
    _ModSpec(['messages', 'validation'], 'messages/validation.json'),
  ];

  static Future<AppLocalizations> load(Locale locale) async {
    final tag = _tagOf(locale);
    final tree = <String, dynamic>{};
    final futures = _modules.map((m) async {
      final raw =
          await rootBundle.loadString('assets/i18n/$tag/${m.assetPath}');
      final parsed = jsonDecode(raw);
      _setNested(tree, m.path, parsed);
    });
    await Future.wait(futures);
    return AppLocalizations._(locale, tree);
  }

  static void _setNested(
      Map<String, dynamic> root, List<String> path, Object? value) {
    var cur = root;
    for (var i = 0; i < path.length - 1; i++) {
      final k = path[i];
      final next = cur[k];
      if (next is Map<String, dynamic>) {
        cur = next;
      } else {
        final fresh = <String, dynamic>{};
        cur[k] = fresh;
        cur = fresh;
      }
    }
    cur[path.last] = value;
  }

  /// Resolve a dotted key, e.g. `core.common.save`. Returns the key itself if
  /// the path is missing or non-string (mirrors Vue behavior of returning
  /// `[MISSING:..]` but we keep it quiet so it can be passed through to the
  /// dashboard untranslated).
  String t(String dotted, {Map<String, Object?>? params}) {
    final raw = _walk(dotted);
    if (raw is! String) {
      if (kDebugMode && raw == null) {
        debugPrint('i18n missing: $dotted (${locale.toLanguageTag()})');
      }
      return dotted;
    }
    if (params == null || params.isEmpty) return raw;
    return raw.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => (params[m.group(1)!] ?? m.group(0)).toString(),
    );
  }

  /// Returns the raw value at the path (Map, List, num, bool, String, ...) so
  /// callers can access label arrays etc. Mirrors `tm` in composables.ts.
  dynamic raw(String dotted) => _walk(dotted);

  dynamic _walk(String dotted) {
    dynamic cur = _tree;
    for (final k in dotted.split('.')) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// Convenience accessor wired through Localizations.of().
  static AppLocalizations of(BuildContext context) {
    final loc =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (loc == null) {
      throw FlutterError(
          'AppLocalizations not found in context. Did you wire AppLocalizationsDelegate into MaterialApp.localizationsDelegates?');
    }
    return loc;
  }
}

/// Ergonomic shortcut. Prefer this in screens:
/// ```dart
/// Text(context.tr('features.mobile.platforms.title'))
/// ```
extension AppLocalizationsX on BuildContext {
  String tr(String dotted, {Map<String, Object?>? params}) =>
      AppLocalizations.of(this).t(dotted, params: params);

  /// Shortcut for the `features.mobile.*` namespace -- 95% of UI labels live
  /// there, so this saves a lot of `features.mobile.` repetition.
  String trM(String mobileDotted, {Map<String, Object?>? params}) =>
      AppLocalizations.of(this)
          .t('features.mobile.$mobileDotted', params: params);
}

class _ModSpec {
  final List<String> path;
  final String assetPath;
  const _ModSpec(this.path, this.assetPath);
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';

  @override
  Future<AppLocalizations> load(Locale locale) {
    return AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(covariant AppLocalizationsDelegate old) => false;
}
