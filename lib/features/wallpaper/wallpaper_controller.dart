/// User-defined app wallpaper: pick an image/GIF from the device, copy it
/// into the app documents dir, and render it behind the home shell.
///
/// Persistence: the wallpaper file lives in `<docs>/wallpaper_<ts>.<ext>`;
/// the chosen filename and blur amount are SharedPreferences entries.
/// Clearing deletes the file and resets the blur.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperState {
  /// Absolute path of the copied wallpaper file, or null when unset.
  final String? path;

  /// True when the file is a GIF (rendered animated).
  final bool isGif;

  /// Blur sigma in logical pixels (0 = sharp).
  final double blur;
  const WallpaperState({this.path, this.isGif = false, this.blur = 0});

  bool get hasWallpaper => path != null;

  WallpaperState copyWith({String? path, bool? isGif, double? blur}) =>
      WallpaperState(
        path: path ?? this.path,
        isGif: isGif ?? this.isGif,
        blur: blur ?? this.blur,
      );
}

class WallpaperController extends Notifier<WallpaperState> {
  static const _fileNameKey = 'astrbot.wallpaper.file';
  static const _blurKey = 'astrbot.wallpaper.blur';

  @override
  WallpaperState build() {
    Future.microtask(_restore);
    return const WallpaperState();
  }

  Future<void> _restore() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString(_fileNameKey);
    final blur = sp.getDouble(_blurKey) ?? 0.0;
    if (name == null || name.isEmpty) {
      state = WallpaperState(blur: blur);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    if (!await file.exists()) {
      // Stale record (file deleted externally) -- drop it.
      await sp.remove(_fileNameKey);
      state = WallpaperState(blur: blur);
      return;
    }
    state = WallpaperState(
      path: file.path,
      isGif: name.toLowerCase().endsWith('.gif'),
      blur: blur,
    );
  }

  /// Copies [sourcePath] into the documents dir, replaces any previous
  /// wallpaper, and activates it. Returns false when the copy fails.
  Future<bool> setFromFile(String sourcePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = _extOf(sourcePath);
      final target = File(
          '${dir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await _deleteCurrent();
      await File(sourcePath).copy(target.path);
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_fileNameKey, target.uri.pathSegments.last);
      state = WallpaperState(
        path: target.path,
        isGif: ext == 'gif',
        blur: state.blur,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBlur(double sigma) async {
    state = state.copyWith(blur: sigma.clamp(0, 30));
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_blurKey, state.blur);
  }

  Future<void> clear() async {
    await _deleteCurrent();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_fileNameKey);
    state = WallpaperState(blur: state.blur);
  }

  Future<void> _deleteCurrent() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString(_fileNameKey);
    if (name == null || name.isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$name');
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort cleanup
    }
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'img';
    return path.substring(dot + 1).toLowerCase();
  }
}

final wallpaperProvider =
    NotifierProvider<WallpaperController, WallpaperState>(
        WallpaperController.new);
