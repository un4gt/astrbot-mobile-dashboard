/// App self-update service against GitHub Releases.
///
/// Flow (modeled on the fluxdo app): fetch the repo's latest release, compare
/// its tag with the installed version, and offer the matching APK asset for
/// download+install via ota_update. Startup auto-checks are gated by a
/// user setting and silent-fail.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/storage/prefs.dart';
import '../../../shared/providers/app_providers.dart';

class ApkAsset {
  final String downloadUrl;
  final String name;
  final int size;
  const ApkAsset({
    required this.downloadUrl,
    required this.name,
    required this.size,
  });
}

class UpdateInfo {
  final String currentVersion;
  final String remoteVersion;
  final String releaseUrl;
  final String releaseNotes;
  final bool hasUpdate;
  final List<ApkAsset> apkAssets;
  const UpdateInfo({
    required this.currentVersion,
    required this.remoteVersion,
    required this.releaseUrl,
    required this.releaseNotes,
    required this.hasUpdate,
    this.apkAssets = const [],
  });
}

class UpdateCheckException implements Exception {
  final String message;
  UpdateCheckException(this.message);
  @override
  String toString() => message;
}

class UpdateService {
  UpdateService(this._dio, this._prefs);

  static const _repository = 'un4gt/astrbot-mobile-dashboard';
  static const _apiUrl =
      'https://api.github.com/repos/$_repository/releases/latest';

  final Dio _dio;
  final Prefs _prefs;

  bool get autoCheck => _prefs.autoCheckUpdate;
  Future<void> setAutoCheck(bool v) => _prefs.setAutoCheckUpdate(v);

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Startup check: honors the auto-check setting; never throws.
  Future<UpdateInfo?> startupAutoCheck() async {
    if (!autoCheck) return null;
    try {
      final info = await check();
      return info.hasUpdate ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// Manual check: always hits the network, throws on failure.
  Future<UpdateInfo> check() async {
    final current = await currentVersion();
    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.get<Map<String, dynamic>>(
        _apiUrl,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'astrbot-mobile',
          },
          validateStatus: (s) => s == 200,
        ),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403 || code == 429) {
        throw UpdateCheckException('rate limited'); // caller maps to i18n
      }
      throw UpdateCheckException('network');
    }
    final data = res.data;
    if (data == null) throw UpdateCheckException('empty response');

    final remote =
        (data['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), '');
    final assets = (data['assets'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    return UpdateInfo(
      currentVersion: current,
      remoteVersion: remote,
      releaseUrl: (data['html_url'] ?? '').toString(),
      releaseNotes: (data['body'] ?? '').toString(),
      hasUpdate: compareVersions(remote, current) > 0,
      apkAssets: [
        for (final a in assets)
          if ((a['name'] ?? '').toString().endsWith('.apk'))
            ApkAsset(
              downloadUrl: (a['browser_download_url'] ?? '').toString(),
              name: (a['name'] ?? '').toString(),
              size: (a['size'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }

  /// Picks the APK asset matching this device's primary ABI; null when the
  /// release ships a single universal APK (fall back to assets.first).
  Future<ApkAsset?> matchingAsset(UpdateInfo info) async {
    if (info.apkAssets.isEmpty) return null;
    if (!Platform.isAndroid) return null;
    // Our releases are universal APKs (flutter build apk without --split-per-abi),
    // so a single asset is the common case.
    if (info.apkAssets.length == 1) return info.apkAssets.first;
    // Multi-ABI fallback: assume the filename contains the abi.
    const archs = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
    for (final arch in archs) {
      for (final a in info.apkAssets) {
        if (a.name.contains(arch)) return a;
      }
    }
    return info.apkAssets.first;
  }

  /// >0 when [v1] is newer than [v2]; tolerates non-numeric segments.
  static int compareVersions(String v1, String v2) {
    int parsePart(String s) =>
        int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final p1 = v1.split('.').map(parsePart).toList();
    final p2 = v2.split('.').map(parsePart).toList();
    final n = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < n; i++) {
      final a = i < p1.length ? p1[i] : 0;
      final b = i < p2.length ? p2[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}

final updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(
    Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    )),
    ref.read(prefsProvider),
  ),
);

/// Whether the startup auto-check ran and found something; watched by the
/// app shell to decide whether to show the update dialog.
final startupUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  return ref.watch(updateServiceProvider).startupAutoCheck();
});

/// Reactive view of the auto-check preference so Settings toggles rebuild
/// immediately and persist through the service.
final autoCheckUpdateProvider = NotifierProvider<AutoCheckUpdateNotifier, bool>(
    AutoCheckUpdateNotifier.new);

class AutoCheckUpdateNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).autoCheckUpdate;

  Future<void> set(bool v) async {
    await ref.read(updateServiceProvider).setAutoCheck(v);
    state = v;
  }
}
