/// Bottom-sheet menu shown when the user taps a markdown link inside a
/// rendered README. Lets them choose an external action so the click never
/// silently jumps out of the app.
library;

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showLinkActionSheet(
  BuildContext context,
  String href,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_browser),
            title: Text(context.trM('common.openInBrowser')),
            subtitle: Text(
              href,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final uri = Uri.tryParse(href);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(context.trM('common.copyLink')),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await Clipboard.setData(ClipboardData(text: href));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.trM('common.linkCopied'))),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(context.trM('common.share')),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await Share.share(href);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
