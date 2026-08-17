/// Update flow UI: the "new version" dialog (install / later / cancel) and
/// the download+install progress dialog driven by ota_update.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

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
/// ota_update writes the file and fires the system installer intent itself;
/// we just surface progress and errors, then close when the install is
/// handed off.
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

class _InstallDialogState extends State<_InstallDialog> {
  String _status = '';
  int _progress = 0;
  bool _error = false;
  StreamSubscription<OtaEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _status = context.trM('update.downloading');
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
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.trM(_error ? 'update.failed' : 'update.downloading')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status),
          const SizedBox(height: 12),
          if (!_error)
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
