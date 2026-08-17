/// Settings page -- theme, locale, change password, reset URL, logout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/ui/change_password_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    // In local debug mode "logging out" means leaving debug mode; there is
    // no real session to end.
    if (ref.read(localDebugProvider)) {
      await _exitLocalDebug(context, ref);
      return;
    }
    await ref.read(tokenProvider.notifier).clear();
    if (context.mounted) context.go('/login');
  }

  Future<void> _exitLocalDebug(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context: context,
      title: context.trM('settings.exitDebugTitle'),
      message: context.trM('settings.exitDebugMessage'),
    );
    if (ok != true) return;
    await ref.read(localDebugProvider.notifier).set(false);
    // The router redirect re-runs once localDebug flips and routes to
    // /setup or /login depending on the saved baseUrl/token.
  }

  Future<void> _toggleLocalDebug(
      BuildContext context, WidgetRef ref, bool v) async {
    if (!v) {
      await _exitLocalDebug(context, ref);
      return;
    }
    await ref.read(localDebugProvider.notifier).set(true);
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.trM('settings.passwordChanged'))),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final baseUrl = ref.watch(baseUrlProvider);
    final localDebug = ref.watch(localDebugProvider);
    final profile = ref.watch(profilesProvider).active;
    final username = ref.watch(activeUsernameProvider) ?? '-';

    return Scaffold(
      appBar: AppBar(title: Text(context.trM('settings.title'))),
      body: ListView(
        children: [
          _section(context, context.trM('settings.account')),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(context.trM('settings.signedInAs')),
            subtitle: Text(localDebug ? 'local-debug' : username),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(context.trM('settings.serverUrl')),
            subtitle: Text(localDebug
                ? context.trM('settings.localDebugSubtitle')
                : (profile != null
                    ? '${profile.name}\n${profile.baseUrl}'
                    : (baseUrl ?? '-'))),
            trailing: const Icon(Icons.chevron_right),
            // In debug mode there is no server to manage -- leaving debug
            // mode is the way back to server configuration.
            onTap: () => localDebug
                ? _exitLocalDebug(context, ref)
                : context.push('/more/settings/servers'),
          ),
          if (!localDebug)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.trM('settings.changePassword')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePassword(context, ref),
            ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(context.trM('settings.diagnostic')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/settings/diagnostic'),
          ),
          ListTile(
            leading:
                Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(
              localDebug
                  ? context.trM('settings.exitDebugTitle')
                  : context.trM('settings.logout'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _logout(context, ref),
          ),
          const Divider(),
          _section(context, context.trM('settings.appearance')),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(context.trM('settings.theme')),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox(),
              onChanged: (m) {
                if (m != null) {
                  ref.read(themeModeProvider.notifier).set(m);
                }
              },
              items: [
                DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(context.trM('settings.themeSystem'))),
                DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(context.trM('settings.themeLight'))),
                DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(context.trM('settings.themeDark'))),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(context.trM('settings.language')),
            trailing: DropdownButton<String?>(
              value: locale?.toLanguageTag(),
              underline: const SizedBox(),
              onChanged: (tag) {
                Locale? next;
                if (tag == 'zh-CN') next = const Locale('zh', 'CN');
                if (tag == 'en-US') next = const Locale('en', 'US');
                ref.read(localeProvider.notifier).set(next);
              },
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(context.trM('settings.languageSystem'))),
                const DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
                const DropdownMenuItem(value: 'en-US', child: Text('English')),
              ],
            ),
          ),
          const Divider(),
          _section(context, context.trM('settings.debug')),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined),
            title: Text(context.trM('settings.localDebug')),
            subtitle: Text(context.trM('settings.localDebugSubtitle')),
            value: localDebug,
            onChanged: (v) => _toggleLocalDebug(context, ref, v),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
