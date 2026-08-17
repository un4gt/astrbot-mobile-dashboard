/// One-shot listener that shows the update dialog after the first frame when
/// the startup auto-check found a newer release.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../data/update_service.dart';
import 'update_flow.dart';

class StartupUpdateGate extends ConsumerStatefulWidget {
  const StartupUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<StartupUpdateGate> createState() => _StartupUpdateGateState();
}

class _StartupUpdateGateState extends ConsumerState<StartupUpdateGate> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame so the dialog has a context and the app is
    // visually up before we interrupt the user.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final info = await ref.read(updateServiceProvider).startupAutoCheck();
    if (!mounted || info == null) return;
    final install = await showUpdateDialog(context, info);
    if (!mounted || !install) return;
    final asset = await ref.read(updateServiceProvider).matchingAsset(info);
    if (!mounted) return;
    if (asset == null) {
      // No usable APK asset -- fall back to opening the release page.
      _snack(context.trM('update.noApkAsset'));
      return;
    }
    await runInstallFlow(context, asset);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
