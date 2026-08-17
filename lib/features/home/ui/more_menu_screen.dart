/// "More" page -- list view of secondary destinations not on the bottom nav.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_MoreEntry>[
      _MoreEntry(Icons.chat_bubble_outline, context.trM('more.chat'), '/more/chat'),
      _MoreEntry(Icons.terminal, context.trM('more.console'), '/more/console'),
      _MoreEntry(Icons.tune, context.trM('more.configuration'), '/more/config'),
      _MoreEntry(Icons.build_outlined, context.trM('more.mcp'), '/more/mcp'),
      _MoreEntry(Icons.face_outlined, context.trM('more.persona'), '/more/persona'),
      _MoreEntry(Icons.history, context.trM('more.conversations'), '/more/conversation'),
      _MoreEntry(Icons.rule, context.trM('more.sessionRules'), '/more/session'),
      _MoreEntry(Icons.menu_book_outlined, context.trM('more.knowledgeBase'), '/more/kb'),
      _MoreEntry(Icons.archive_outlined, context.trM('more.knowledgeBaseLegacy'), '/more/alkaid-kb'),
      _MoreEntry(Icons.psychology_alt_outlined, context.trM('more.longTermMemory'), '/more/memory'),
      _MoreEntry(Icons.info_outline, context.trM('more.aboutUpdate'), '/more/about'),
      _MoreEntry(Icons.settings, context.trM('more.settings'), '/more/settings'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.trM('more.title'))),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = entries[i];
          return ListTile(
            leading: Icon(e.icon),
            title: Text(e.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(e.path),
          );
        },
      ),
    );
  }
}

class _MoreEntry {
  final IconData icon;
  final String title;
  final String path;
  _MoreEntry(this.icon, this.title, this.path);
}
