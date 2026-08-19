/// Shared confirm dialog. Returns true on confirm, false/null on cancel.
library;

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      // Defaults resolve here so every caller gets localized buttons.
      final confirm = confirmLabel ?? ctx.trM('common.confirm');
      final cancel = cancelLabel ?? ctx.trM('common.cancel');
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      );
    },
  );
  return res == true;
}
