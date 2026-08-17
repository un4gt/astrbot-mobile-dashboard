/// Top-level Riverpod providers shared across features:
/// prefs, secure storage, server profiles, baseUrl, token, locale, themeMode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs.dart';
import '../../core/storage/profile_store.dart';
import '../../core/storage/secure_storage.dart';

/// Provided once at app boot via overrideWithValue in main.dart.
final prefsProvider = Provider<Prefs>((ref) {
  throw UnimplementedError('prefsProvider must be overridden at bootstrap');
});

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final profileStoreProvider = Provider<ProfileStore>(
    (ref) => ProfileStore(ref.read(prefsProvider), ref.read(secureStorageProvider)));

// Server profiles (multi-server support) --------------------------------------

/// Immutable snapshot of the profile list + which one is active. Bumping this
/// state is what rebuilds everything downstream (dio, services, screens).
class ProfilesState {
  final List<ServerProfile> profiles;
  final String? activeId;
  const ProfilesState({required this.profiles, this.activeId});

  ServerProfile? get active =>
      profiles.firstWhereOrNull((p) => p.id == activeId) ??
      (profiles.isEmpty ? null : profiles.first);
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

class ProfilesNotifier extends Notifier<ProfilesState> {
  @override
  ProfilesState build() {
    final store = ref.read(profileStoreProvider);
    return ProfilesState(
      profiles: store.loadProfiles(),
      activeId: store.loadActiveId(),
    );
  }

  Future<void> _reload() async {
    final store = ref.read(profileStoreProvider);
    state = ProfilesState(
      profiles: store.loadProfiles(),
      activeId: store.loadActiveId(),
    );
  }

  Future<ServerProfile> upsert({
    String? id,
    required String name,
    required String baseUrl,
    bool activate = true,
  }) async {
    final p = await ref
        .read(profileStoreProvider)
        .upsert(id: id, name: name, baseUrl: baseUrl, activate: activate);
    await _reload();
    return p;
  }

  Future<void> remove(String id) async {
    await ref.read(profileStoreProvider).remove(id);
    await _reload();
  }

  /// Switch the active server. Token/baseUrl providers rebuild off the new
  /// active id, which rebuilds dio and every service below it; the router
  /// redirect then routes to dashboard or login based on the new token.
  Future<void> switchTo(String id) async {
    await ref.read(profileStoreProvider).switchTo(id);
    await _reload();
  }
}

final profilesProvider =
    NotifierProvider<ProfilesNotifier, ProfilesState>(ProfilesNotifier.new);

// Base URL ----------------------------------------------------------------------

/// Base URL of the active profile. Derived (not free-standing): it follows the
/// active profile so a profile switch retargets every network call.
class BaseUrlNotifier extends Notifier<String?> {
  @override
  String? build() {
    final active = ref.watch(profilesProvider).active;
    if (active != null) return active.baseUrl;
    // Legacy single-server installations have no profile record yet.
    return ref.read(prefsProvider).baseUrl;
  }

  Future<void> set(String url) async {
    final activeId = ref.read(profilesProvider).active?.id;
    if (activeId != null) {
      // Update the active profile's URL in place.
      final store = ref.read(profileStoreProvider);
      final p = store.loadProfiles().firstWhereOrNull((x) => x.id == activeId);
      if (p != null) {
        await store.upsert(id: activeId, name: p.name, baseUrl: url);
        await ref.read(profilesProvider.notifier)._reload();
        return;
      }
    }
    await ref.read(prefsProvider).setBaseUrl(url);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await ref.read(prefsProvider).clearBaseUrl();
    ref.invalidateSelf();
  }
}

final baseUrlProvider =
    NotifierProvider<BaseUrlNotifier, String?>(BaseUrlNotifier.new);

// Local debug (mock data) --------------------------------------------------------

/// When enabled, every API call is answered by built-in mock data and the
/// router skips the baseUrl/token gates, so the app can be explored without
/// an AstrBot server.
class LocalDebugNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).localDebug;

  Future<void> set(bool v) async {
    await ref.read(prefsProvider).setLocalDebug(v);
    state = v;
  }
}

final localDebugProvider =
    NotifierProvider<LocalDebugNotifier, bool>(LocalDebugNotifier.new);

// Token ---------------------------------------------------------------------------

/// Bearer token of the ACTIVE profile. Re-reads from secure storage whenever
/// the active profile changes.
class TokenNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final active = ref.watch(profilesProvider).active;
    if (active == null) {
      return ref.read(secureStorageProvider).readToken();
    }
    return ref.read(profileStoreProvider).readToken(active.id);
  }

  Future<void> set(String token) async {
    final active = ref.read(profilesProvider).active;
    if (active != null) {
      await ref.read(profileStoreProvider).writeToken(active.id, token);
    } else {
      await ref.read(secureStorageProvider).writeToken(token);
    }
    state = AsyncData(token);
  }

  Future<void> clear() async {
    final active = ref.read(profilesProvider).active;
    if (active != null) {
      await ref.read(profileStoreProvider).clearToken(active.id);
    } else {
      await ref.read(secureStorageProvider).clearToken();
    }
    state = const AsyncData(null);
  }
}

final tokenProvider =
    AsyncNotifierProvider<TokenNotifier, String?>(TokenNotifier.new);

/// Synchronous "currently authenticated?" accessor for the router redirect.
/// While the AsyncNotifier is loading we treat it as "no token" -- the router
/// will re-evaluate once the future settles.
final hasTokenProvider = Provider<bool>((ref) {
  return ref.watch(tokenProvider).maybeWhen(
        data: (t) => t != null && t.isNotEmpty,
        orElse: () => false,
      );
});

// Theme ---------------------------------------------------------------------------

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(prefsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    await ref.read(prefsProvider).setThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Locale ---------------------------------------------------------------------------

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final tag = ref.read(prefsProvider).localeTag;
    return _parse(tag);
  }

  Future<void> set(Locale? locale) async {
    await ref.read(prefsProvider).setLocaleTag(locale?.toLanguageTag());
    state = locale;
  }

  static Locale? _parse(String? tag) {
    if (tag == null || tag.isEmpty) return null;
    final parts = tag.split(RegExp('[-_]'));
    if (parts.length >= 2) return Locale(parts[0], parts[1]);
    return Locale(parts.first);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

// Active profile display helpers -----------------------------------------------------

/// Username of the active profile (per-profile record, legacy fallback).
class ActiveUsernameNotifier extends Notifier<String?> {
  @override
  String? build() {
    final active = ref.watch(profilesProvider).active;
    if (active != null) {
      return ref.read(profileStoreProvider).readUsername(active.id) ??
          ref.read(prefsProvider).username;
    }
    return ref.read(prefsProvider).username;
  }

  Future<void> set(String? username) async {
    final active = ref.read(profilesProvider).active;
    if (active != null && username != null) {
      await ref.read(profileStoreProvider).writeUsername(active.id, username);
    } else {
      await ref.read(prefsProvider).setUsername(username);
    }
    state = username;
  }
}

final activeUsernameProvider =
    NotifierProvider<ActiveUsernameNotifier, String?>(ActiveUsernameNotifier.new);

/// "Change default password" hint flag of the active profile.
class ActivePwdHintNotifier extends Notifier<bool> {
  @override
  bool build() {
    final active = ref.watch(profilesProvider).active;
    if (active != null) {
      return ref.read(profileStoreProvider).readPwdHint(active.id) ||
          ref.read(prefsProvider).changePwdHint;
    }
    return ref.read(prefsProvider).changePwdHint;
  }

  Future<void> set(bool v) async {
    final active = ref.read(profilesProvider).active;
    if (active != null) {
      await ref.read(profileStoreProvider).writePwdHint(active.id, v);
    } else {
      await ref.read(prefsProvider).setChangePwdHint(v);
    }
    state = v;
  }
}

final activePwdHintProvider =
    NotifierProvider<ActivePwdHintNotifier, bool>(ActivePwdHintNotifier.new);
