/// Application routing. Mirrors the Vue dashboard route layout but with
/// a 5-tab bottom-nav shell instead of a sidebar:
///   /setup     -- first-run server URL picker (no shell)
///   /login     -- credentials (no shell)
///   /dashboard, /platforms, /providers, /plugins, /more  -- bottom-nav tabs
///   /more/* -- secondary destinations pushed onto the More branch.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/ui/login_screen.dart';
import '../../features/chat/ui/chat_screen.dart';
import '../../features/config/ui/system_config_screen.dart';
import '../../features/console/ui/console_screen.dart';
import '../../features/conversation/ui/conversation_detail_screen.dart';
import '../../features/conversation/ui/conversation_list_screen.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/diagnostic/ui/diagnostic_screen.dart';
import '../../features/home/ui/home_shell.dart';
import '../../features/home/ui/more_menu_screen.dart';
import '../../features/kb/ui/kb_list_screen.dart';
import '../../features/mcp/ui/tool_use_screen.dart';
import '../../features/persona/ui/persona_form_screen.dart';
import '../../features/persona/ui/persona_list_screen.dart';
import '../../features/persona/ui/persona_view_screen.dart';
import '../../features/placeholders.dart';
import '../../features/platform/ui/edit_platform_screen.dart';
import '../../features/platform/ui/platform_list_screen.dart';
import '../../features/platform/ui/select_platform_template_screen.dart';
import '../../features/plugin/ui/installed_plugins_screen.dart';
import '../../features/plugin/ui/plugin_detail_screen.dart';
import '../../features/plugin/ui/plugin_market_screen.dart';
import '../../features/plugin/ui/plugin_readme_screen.dart';
import '../../features/provider/ui/edit_provider_screen.dart';
import '../../features/provider/ui/provider_list_screen.dart';
import '../../features/provider/ui/select_provider_template_screen.dart';
import '../../features/session/ui/session_rule_editor_screen.dart';
import '../../features/session/ui/session_rules_screen.dart';
import '../../features/settings/ui/profile_manage_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/setup/ui/setup_screen.dart';
import '../../features/system/ui/about_update_screen.dart';
import '../../shared/providers/app_providers.dart';

/// ChangeNotifier-style listenable that pokes GoRouter whenever auth, URL,
/// active profile, or local-debug state shifts so the redirect re-runs.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(baseUrlProvider, (_, _) => notifyListeners());
    ref.listen(tokenProvider, (_, _) => notifyListeners());
    ref.listen(localDebugProvider, (_, _) => notifyListeners());
    // Profile switches change baseUrl+token providers too, but those resolve
    // asynchronously -- listen to the source of truth directly.
    ref.listen(profilesProvider, (_, _) => notifyListeners());
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      // Local debug mode answers everything with mock data -- skip the
      // setup/login gates entirely.
      if (ref.read(localDebugProvider)) {
        return (state.matchedLocation == '/setup' ||
                state.matchedLocation == '/login')
            ? '/dashboard'
            : null;
      }
      final baseUrl = ref.read(baseUrlProvider);
      final tokenAsync = ref.read(tokenProvider);
      // While the token is loading from secure storage, hold the user on the
      // current route -- redirect re-runs once the future resolves.
      if (tokenAsync.isLoading) return null;
      final hasToken = tokenAsync.valueOrNull != null &&
          (tokenAsync.valueOrNull as String).isNotEmpty;
      final loc = state.matchedLocation;
      final atSetup = loc == '/setup';
      final atLogin = loc == '/login';

      if (baseUrl == null || baseUrl.isEmpty) {
        return atSetup ? null : '/setup';
      }      if (!hasToken) {
        return atLogin ? null : '/login';
      }
      if (atSetup || atLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/platforms',
              builder: (_, _) => const PlatformListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const SelectPlatformTemplateScreen(),
                ),
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => _buildPlatformEditor(state.extra),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/providers',
              builder: (_, _) => const ProviderListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, _) => const SelectProviderTemplateScreen(),
                ),
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => _buildProviderEditor(state.extra),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/plugins',
              builder: (_, _) => const InstalledPluginsScreen(),
              routes: [
                GoRoute(
                  path: 'market',
                  builder: (_, _) => const PluginMarketScreen(),
                  routes: [
                    GoRoute(
                      path: 'readme',
                      builder: (_, state) => _buildReadme(state.extra,
                          fromMarket: true),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'readme',
                  builder: (_, state) =>
                      _buildReadme(state.extra, fromMarket: false),
                ),
                GoRoute(
                  path: 'detail',
                  builder: (_, state) {
                    final raw = state.extra;
                    if (raw is Map<String, dynamic>) {
                      return PluginDetailScreen(raw: raw);
                    }
                    if (raw is Map) {
                      return PluginDetailScreen(
                          raw: Map<String, dynamic>.from(raw));
                    }
                    return const Scaffold(
                      body: Center(child: Text('Missing plugin payload.')),
                    );
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (_, _) => const MoreMenuScreen(),
              routes: [
                GoRoute(
                  path: 'console',
                  builder: (_, _) => const ConsoleScreen(),
                ),
                GoRoute(
                  path: 'chat',
                  builder: (_, _) => const ChatScreen(),
                ),
                GoRoute(
                  path: 'config',
                  builder: (_, _) => const SystemConfigScreen(),
                ),
                GoRoute(
                  path: 'mcp',
                  builder: (_, _) => const ToolUseScreen(),
                ),
                GoRoute(
                  path: 'persona',
                  builder: (_, _) => const PersonaListScreen(),
                  routes: [
                    GoRoute(
                      path: 'view',
                      builder: (_, state) {
                        final raw = state.extra;
                        if (raw is Map) {
                          return PersonaViewScreen(
                            persona: Map<String, dynamic>.from(raw),
                          );
                        }
                        return const Scaffold(
                          body: Center(child: Text('Missing persona payload.')),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'edit',
                      builder: (_, state) => PersonaFormScreen(
                        initial: state.extra is Map
                            ? Map<String, dynamic>.from(state.extra as Map)
                            : null,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'conversation',
                  builder: (_, _) => const ConversationListScreen(),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (_, state) {
                        final raw = state.extra;
                        if (raw is Map) {
                          return ConversationDetailScreen(
                            summary: Map<String, dynamic>.from(raw),
                          );
                        }
                        return const Scaffold(
                          body: Center(
                              child: Text('Missing conversation payload.')),
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'session',
                  builder: (_, _) => const SessionRulesScreen(),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, state) {
                        final raw = state.extra;
                        if (raw is Map) {
                          return SessionRuleEditorScreen(
                            payload: Map<String, dynamic>.from(raw),
                          );
                        }
                        return const Scaffold(
                          body: Center(
                              child: Text('Missing session payload.')),
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'kb',
                  builder: (_, _) => const KbListScreen(),
                ),
                GoRoute(
                  path: 'alkaid-kb',
                  builder: (_, _) => const AlkaidKbStubScreen(),
                ),
                GoRoute(
                  path: 'memory',
                  builder: (_, _) => const MemoryStubScreen(),
                ),
                GoRoute(
                  path: 'about',
                  builder: (_, _) => const AboutUpdateScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (_, _) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'diagnostic',
                      builder: (_, _) => const DiagnosticScreen(),
                    ),
                    GoRoute(
                      path: 'servers',
                      builder: (_, _) => const ProfileManageScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Resolves the `extra` payload from `/platforms/edit`. Two shapes supported:
///   - `Map<String, dynamic>` -- existing platform (edit flow)
///   - `{config, isNew: true, templateName}` -- newly cloned template
Widget _buildPlatformEditor(Object? extra) {
  if (extra is Map && extra['isNew'] == true) {
    final cfg = Map<String, dynamic>.from(extra['config'] as Map);
    return EditPlatformScreen(
      config: cfg,
      isNew: true,
      templateName: extra['templateName']?.toString(),
    );
  }
  if (extra is Map) {
    final raw = Map<String, dynamic>.from(extra);
    return EditPlatformScreen(
      config: raw,
      isNew: false,
      originalId: raw['id']?.toString(),
    );
  }
  return const Scaffold(body: Center(child: Text('Missing platform payload.')));
}

Widget _buildProviderEditor(Object? extra) {
  if (extra is Map && extra['isNew'] == true) {
    final cfg = Map<String, dynamic>.from(extra['config'] as Map);
    return EditProviderScreen(
      config: cfg,
      isNew: true,
      templateName: extra['templateName']?.toString(),
    );
  }
  if (extra is Map) {
    final raw = Map<String, dynamic>.from(extra);
    return EditProviderScreen(
      config: raw,
      isNew: false,
      originalId: raw['id']?.toString(),
    );
  }
  return const Scaffold(body: Center(child: Text('Missing provider payload.')));
}

/// Build PluginReadmeScreen from `state.extra = {name, repo}`.
Widget _buildReadme(Object? extra, {required bool fromMarket}) {
  if (extra is Map) {
    final name = extra['name']?.toString() ?? '';
    final repo = extra['repo']?.toString();
    if (name.isNotEmpty) {
      return PluginReadmeScreen(
        pluginName: name,
        repoUrl: repo,
        fromMarket: fromMarket,
      );
    }
  }
  return const Scaffold(body: Center(child: Text('Missing plugin payload.')));
}
