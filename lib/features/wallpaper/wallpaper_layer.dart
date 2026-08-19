/// Full-bleed wallpaper layer for the home shell.
///
/// Renders the user's chosen image (static) or GIF (animated, paused while
/// the app is backgrounded to save battery) with an optional blur scrim.
/// Isolated in a RepaintBoundary so the animated layer never invalidates
/// the content tree above it.
library;

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_view/gif_view.dart';

import 'wallpaper_controller.dart';

class WallpaperLayer extends ConsumerStatefulWidget {
  const WallpaperLayer({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WallpaperLayer> createState() => _WallpaperLayerState();
}

class _WallpaperLayerState extends ConsumerState<WallpaperLayer>
    with WidgetsBindingObserver {
  final GifController _gifCtrl = GifController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gifCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // GIF decoding keeps burning battery in the background otherwise.
    if (state == AppLifecycleState.resumed) {
      _gifCtrl.play();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _gifCtrl.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref.watch(wallpaperProvider);

    if (!wallpaper.hasWallpaper || wallpaper.path == null) {
      return widget.child;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: _buildWallpaper(context, wallpaper),
          ),
        ),
        // Scaffolds inside the shell (each tab screen has its own) default
        // to an opaque surface color which would cover the wallpaper.
        // Overriding the theme's scaffoldBackgroundColor (and the nav bar's
        // container color) to translucent values makes every nested layer
        // see-through without touching the screens themselves.
        Positioned.fill(
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor:
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
              ),
            ),
            child: widget.child,
          ),
        ),
      ],
    );
  }

  Widget _buildWallpaper(BuildContext context, WallpaperState w) {
    final Widget image;
    if (w.isGif) {
      image = GifView(
        image: FileImage(File(w.path!)),
        controller: _gifCtrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else {
      final mq = MediaQuery.of(context);
      image = Image.file(
        File(w.path!),
        fit: BoxFit.cover,
        // Downsample to screen resolution-ish; keeps 4K picks from
        // exploding memory.
        cacheWidth:
            (mq.size.width * mq.devicePixelRatio).round(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }

    if (w.blur > 0) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: w.blur, sigmaY: w.blur),
        child: image,
      );
    }
    return image;
  }
}
