/// Bottom-navigation shell wrapping Dashboard / Platforms / Providers /
/// Plugins / More tabs as 5 independent navigation branches.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../wallpaper/wallpaper_controller.dart';
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

    final hasWallpaper = ref.watch(
        wallpaperProvider.select((w) => w.hasWallpaper));
    // See-through so the wallpaper shows through the nav shell; the tint
    // keeps content readable on busy images.
    final surface = Theme.of(context).colorScheme.surface;
    final bg = hasWallpaper ? surface.withValues(alpha: 0.86) : surface;

    return WallpaperLayer(
      child: Scaffold(
        backgroundColor: bg,
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          backgroundColor: bg,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: destinations,
        ),
      ),
    );
  }
}
