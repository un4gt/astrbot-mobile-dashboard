/// Bottom sheet listing configured server profiles for quick switching.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';

/// Shows the profile switcher anchored to the bottom of the screen.
Future<void> showServerSwitcher(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const _ServerSwitcherSheet(),
  );
}

class _ServerSwitcherSheet extends ConsumerWidget {
  const _ServerSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesProvider);
    final active = state.active;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              context.trM('profiles.switchTitle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (state.profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(context.trM('profiles.empty')),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final p in state.profiles)
                    ListTile(
                      leading: Icon(
                        p.id == active?.id
                            ? Icons.check_circle
                            : Icons.dns_outlined,
                        color:
                            p.id == active?.id ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        p.baseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (p.id != active?.id) {
                          ref.read(profilesProvider.notifier).switchTo(p.id);
                        }
                      },
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(context.trM('profiles.manage')),
            onTap: () {
              Navigator.pop(context);
              context.push('/more/settings/servers');
            },
          ),
        ],
      ),
    );
  }
}
