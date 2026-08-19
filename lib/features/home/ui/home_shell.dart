/// Bottom-navigation shell wrapping Dashboard / Platforms / Providers /
/// Plugins / More tabs as 5 independent navigation branches.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../wallpaper/wallpaper_layer.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _onTap(int idx) {
    navigationShell.goBranch(
      idx,
      initialLocation: idx == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: context.tr('core.navigation.dashboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.smart_toy_outlined),
        selectedIcon: const Icon(Icons.smart_toy),
        label: context.tr('core.navigation.platforms'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.psychology_outlined),
        selectedIcon: const Icon(Icons.psychology),
        label: context.tr('core.navigation.providers'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.extension_outlined),
        selectedIcon: const Icon(Icons.extension),
        label: context.tr('core.navigation.extension'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.more_horiz),
        label: context.trM('more.title'),
      ),
    ];

    return Scaffold(
      // WallpaperLayer wraps the branch content (not the whole scaffold):
      // this shell's own scaffold background then paints BEHIND the
      // wallpaper while each tab's translucent scaffold paints exactly one
      // scrim on top of it. Wrapping the outside instead would stack two
      // scrims and hide the wallpaper almost completely.
      body: WallpaperLayer(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: destinations,
      ),
    );
  }
}
