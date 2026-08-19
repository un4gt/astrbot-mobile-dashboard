/// Update flow UI: the "new version" dialog (install / later / cancel) and
/// the download+install progress dialog driven by ota_update.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/i18n/app_localizations.dart';
import '../data/update_service.dart';

/// Shows the update dialog. Returns true when the user chose to install.
Future<bool> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  final cs = Theme.of(context).colorScheme;
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.trM('update.availableTitle',
          params: {'version': info.remoteVersion})),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.trM('update.currentIs',
                    params: {'version': info.currentVersion}),
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (info.releaseNotes.trim().isNotEmpty) ...[
                Text(
                  info.releaseNotes.trim(),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: Text(context.trM('update.cancel')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, 'later'),
          child: Text(context.trM('update.later')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, 'install'),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(context.trM('update.install')),
        ),
      ],
    ),
  );
  return action == 'install';
}

/// Download + install the APK with a progress dialog.
///
/// Android 8+ requires the user to grant "install unknown apps" per
/// application; without it the installer intent ota_update fires after the
/// download is silently rejected. [_InstallDialog] checks the permission
/// when it opens, walks the user to the system settings page, re-checks
/// when they come back, and only then starts the download.
Future<void> runInstallFlow(BuildContext context, ApkAsset asset) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InstallDialog(asset: asset),
  );
}

class _InstallDialog extends StatefulWidget {
  const _InstallDialog({required this.asset});

  final ApkAsset asset;

  @override
  State<_InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<_InstallDialog>
    with WidgetsBindingObserver {
  String _status = '';
  int _progress = 0;
  bool _error = false;
  bool _awaitingPermission = false;
  StreamSubscription<OtaEvent>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = context.trM('update.downloading');
    Future.microtask(_ensurePermissionThenDownload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  /// Android 8+ gate: without the "install unknown apps" grant the
  /// installer intent fired after the download is silently rejected, which
  /// is exactly the "downloaded but nothing happens" failure. Check before
  /// downloading; if missing, send the user to the settings page and
  /// re-check when they return.
  Future<void> _ensurePermissionThenDownload() async {
    if (!Platform.isAndroid) {
      _startDownload();
      return;
    }
    if ((await Permission.requestInstallPackages.status).isGranted) {
      _startDownload();
      return;
    }
    if (!mounted) return;
    setState(() => _awaitingPermission = true);
    final goSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.trM('update.permissionTitle')),
        content: Text(context.trM('update.permissionMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.trM('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.trM('update.permissionGoSettings')),
          ),
        ],
      ),
    );
    if (goSettings != true) {
      if (mounted) Navigator.pop(context);
      return;
    }
    // Lands on this app's details page; the user toggles "Allow from this
    // source" and returns to the app. openAppSettings() may resolve
    // immediately on some ROMs, so also re-check on every lifecycle resume.
    _settingsLaunched = true;
    setState(() => _status = context.trM('update.permissionWaiting'));
    await openAppSettings();
  }

  bool _settingsLaunched = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsLaunched) {
      _settingsLaunched = false;
      _recheckPermissionAfterSettings();
    }
  }

  Future<void> _recheckPermissionAfterSettings() async {
    // Resolve strings before the async gap so nothing touches context
    // across it.
    final errPermission = context.trM('update.errPermission');
    if (!mounted) return;
    if ((await Permission.requestInstallPackages.status).isGranted) {
      setState(() => _awaitingPermission = false);
      _startDownload();
    } else {
      setState(() => _awaitingPermission = false);
      _fail(errPermission);
    }
  }

  void _startDownload() {
    if (!mounted) return;
    _sub = OtaUpdate().execute(widget.asset.downloadUrl).listen(
      (event) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            setState(() {
              _progress = int.tryParse(event.value ?? '') ?? _progress;
            });
            break;
          case OtaStatus.INSTALLING:
            setState(() {
              _status = context.trM('update.installing');
              _progress = 100;
            });
            break;
          case OtaStatus.INSTALLATION_DONE:
            // System installer took over; close our dialog.
            Navigator.pop(context);
            break;
          case OtaStatus.INSTALLATION_ERROR:
            _fail(context.trM('update.errInternal'));
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
            _fail(context.trM('update.errAlreadyRunning'));
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            _fail(context.trM('update.errPermission'));
            break;
          case OtaStatus.INTERNAL_ERROR:
            _fail(event.value ?? context.trM('update.errInternal'));
            break;
          case OtaStatus.DOWNLOAD_ERROR:
            _fail(event.value ?? context.trM('update.errDownload'));
            break;
          case OtaStatus.CANCELED:
            if (mounted) Navigator.pop(context);
            break;
          case OtaStatus.CHECKSUM_ERROR:
            _fail(context.trM('update.errChecksum'));
            break;
        }
      },
      onError: (Object e) => _fail(e.toString()),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _error = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.trM(_error
          ? 'update.failed'
          : _awaitingPermission
              ? 'update.permissionTitle'
              : 'update.downloading')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status),
          const SizedBox(height: 12),
          if (!_error && !_awaitingPermission)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress / 100 : null,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _sub?.cancel();
            Navigator.pop(context);
          },
          child: Text(context.trM(_error
              ? 'common.close'
              : 'common.cancel')),
        ),
      ],
    );
  }
}
