/// About + Update + Restart -- single page covering AboutPage.vue and the
/// header's "check for update" / "restart" buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/system_service.dart';

class AboutUpdateScreen extends ConsumerStatefulWidget {
  const AboutUpdateScreen({super.key});

  @override
  ConsumerState<AboutUpdateScreen> createState() => _AboutUpdateScreenState();
}

class _AboutUpdateScreenState extends ConsumerState<AboutUpdateScreen> {
  UpdateInfo? _update;
  bool _checking = false;
  String? _checkError;
  bool _restarting = false;
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      _update = await ref.read(systemServiceProvider).checkUpdate();
    } on ApiException catch (e) {
      _checkError = e.message;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _restart() async {
    final ok = await showConfirmDialog(
      context: context,
      title: context.trM('system.restartTitle'),
      message: context.trM('system.restartMessage'),
      destructive: true,
      confirmLabel: context.trM('system.restart'),
      cancelLabel: context.trM('common.cancel'),
    );
    if (!ok) return;
    setState(() => _restarting = true);
    try {
      await ref.read(systemServiceProvider).restartCore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.trM('system.restartRequested'))),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(versionInfoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.trM('system.aboutUpdate'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AstrBot',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  version.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child:
                          LinearProgressIndicator(minHeight: 2),
                    ),
                    error: (e, _) => Text(
                      e is ApiException ? e.message : e.toString(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    data: (v) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<PackageInfo>(
                          future: _packageInfo,
                          builder: (_, snap) {
                            final info = snap.data;
                            if (info == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(context.trM('system.appVersion', params: {'version': info.version, 'build': info.buildNumber.toString()})),
                            );
                          },
                        ),
                        Text(context.trM('system.coreVersion',
                            params: {'v': v.version})),
                        Text(context.trM('system.dashboardVersion',
                            params: {'v': v.dashboardVersion})),
                        if (v.needMigration)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              context.trM('system.needMigration'),
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.trM('system.update'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_checkError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _checkError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  if (_update != null) ...[
                    Text(_update!.message),
                    const SizedBox(height: 4),
                    if (_update!.hasNewVersion)
                      Text(context.trM('system.newCore')),
                    if (_update!.dashboardHasNewVersion)
                      Text(context.trM('system.newDashboard')),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _checking ? null : _check,
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        label: Text(context.trM('system.checkForUpdates')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.trM('system.updatesRunOnServer'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.trM('system.system'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _restarting ? null : _restart,
                    icon: _restarting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restart_alt),
                    label: Text(context.trM('system.restart')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.trM('system.project'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                        Uri.parse('https://github.com/AstrBotDevs/AstrBot')),
                    icon: const Icon(Icons.code),
                    label: Text(context.trM('system.github')),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse('https://astrbot.app')),
                    icon: const Icon(Icons.public),
                    label: Text(context.trM('system.documentation')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
