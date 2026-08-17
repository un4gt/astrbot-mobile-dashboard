/// Bootstraps shared services then runs the AstrBot mobile app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/prefs.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await Prefs.create();
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const AstrBotApp(),
    ),
  );
}
