// Verifies nested `object`/`config_template` sections (plugin
// "second-level menus") render as inline sub-forms and recurse.
//
// Runs as a single testWidgets: AppLocalizationsDelegate caches loaded
// bundles in static state, so multiple widget tests in one file can bleed
// locale state between each other.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astrbot_mobile/core/i18n/app_localizations.dart';
import 'package:astrbot_mobile/features/config/ui/config_form.dart';

Widget _host(Widget body) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en', 'US'),
      home: Scaffold(body: body),
    );

void main() {
  testWidgets('nested sections render once and recurse', (tester) async {
    // 1) object-typed section + a sibling plain field.
    await tester.pumpWidget(_host(ConfigForm(
      sectionMeta: {
        'type': 'object',
        'items': {
          'settings': {
            'type': 'object',
            'description': 'Server settings',
            'items': {
              'host': {'type': 'string', 'description': 'Host'},
            },
          },
          'plain': {'type': 'string', 'description': 'Plain field'},
        },
      },
      initial: {
        'settings': {'host': 'localhost'},
        'plain': 'x',
      },
      mode: ConfigFormMode.configKeys,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Server settings'), findsOneWidget,
        reason: 'nested section title should render exactly once');
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Plain field'), findsOneWidget);

    // 2) config_template-typed section.
    await tester.pumpWidget(_host(ConfigForm(
      sectionMeta: {
        'type': 'object',
        'items': {
          'settings': {
            'type': 'config_template',
            'description': 'Server settings',
            'items': {
              'host': {'type': 'string', 'description': 'Host'},
            },
          },
        },
      },
      initial: {
        'settings': {'host': 'localhost'},
      },
      mode: ConfigFormMode.configKeys,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Server settings'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);

    // 3) two levels of nesting. pumpWidget replaces the subtree, so the
    // new ConfigForm rebuilds with fresh state.
    await tester.pumpWidget(_host(ConfigForm(
      sectionMeta: {
        'type': 'object',
        'items': {
          'level1': {
            'type': 'object',
            'description': 'Level 1',
            'items': {
              'level2': {
                'type': 'object',
                'description': 'Level 2',
                'items': {
                  'leaf': {'type': 'string', 'description': 'Leaf'},
                },
              },
            },
          },
        },
      },
      initial: {
        'level1': {
          'level2': {'leaf': 'v'},
        },
      },
      mode: ConfigFormMode.configKeys,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Leaf'), findsOneWidget);
  });
}
