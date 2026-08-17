/// Multi-server profile store.
///
/// Every "profile" is one AstrBot server connection: a user-chosen name, the
/// base URL, and per-profile credentials (username + bearer token). All data
/// displayed by the app is fetched live from the active profile's server, so
/// switching profiles switches every screen; nothing but these small records
/// is stored on-device.
///
/// Persistence:
///   - profile list + active id  -> SharedPreferences (non-secret)
///   - username / change-pwd-hint per profile -> SharedPreferences
///   - bearer token per profile  -> flutter_secure_storage (key includes id)
library;

import 'dart:convert';
import 'dart:math';

import 'prefs.dart';
import 'secure_storage.dart';

class ServerProfile {
  final String id;
  final String name;
  final String baseUrl;

  const ServerProfile({required this.id, required this.name, required this.baseUrl});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'baseUrl': baseUrl};

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        baseUrl: (json['baseUrl'] ?? '').toString(),
      );

  ServerProfile copyWith({String? name, String? baseUrl}) => ServerProfile(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
      );
}

class ProfileStore {
  ProfileStore(this._prefs, this._secure);

  static final _rand = Random();

  final Prefs _prefs;
  final SecureStorage _secure;

  // Profile list ---------------------------------------------------------------

  List<ServerProfile> loadProfiles() {
    final raw = _prefs.raw(PrefKeys.profilesJson);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => ServerProfile.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.id.isNotEmpty && p.baseUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveProfiles(List<ServerProfile> profiles) async {
    await _prefs.setStringRaw(
        PrefKeys.profilesJson, jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }

  String? loadActiveId() {
    final v = _prefs.raw(PrefKeys.activeProfileId);
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  Future<void> _setActiveId(String? id) async {
    if (id == null) {
      await _prefs.removeRaw(PrefKeys.activeProfileId);
    } else {
      await _prefs.setStringRaw(PrefKeys.activeProfileId, id);
    }
  }

  // CRUD ------------------------------------------------------------------------

  ServerProfile? activeProfile() {
    final profiles = loadProfiles();
    final id = loadActiveId();
    if (profiles.isEmpty) return null;
    return profiles.firstWhereOrNull((p) => p.id == id) ?? profiles.first;
  }

  /// Adds or replaces a profile. When it is brand new it becomes the active
  /// profile (the user just configured it, they want to use it).
  Future<ServerProfile> upsert({
    String? id,
    required String name,
    required String baseUrl,
    bool activate = true,
  }) async {
    final profiles = [...loadProfiles()];
    final cleaned = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (id != null) {
      final idx = profiles.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        final updated = profiles[idx].copyWith(name: name, baseUrl: cleaned);
        profiles[idx] = updated;
        await _saveProfiles(profiles);
        if (activate) await _setActiveId(updated.id);
        return updated;
      }
    }
    final created = ServerProfile(
      // Timestamp + random suffix: two profiles created in the same
      // millisecond (or after a clock rollback) must never share an id.
      id: id ??
          'p${DateTime.now().millisecondsSinceEpoch}'
          '${_rand.nextInt(0x100000).toRadixString(16).padLeft(5, '0')}',
      name: name,
      baseUrl: cleaned,
    );
    profiles.add(created);
    await _saveProfiles(profiles);
    if (activate) await _setActiveId(created.id);
    return created;
  }

  Future<void> remove(String id) async {
    final profiles = [...loadProfiles()];
    profiles.removeWhere((p) => p.id == id);
    await _saveProfiles(profiles);
    await _secure.delete(_tokenKey(id));
    await _prefs.removeRaw(_usernameKey(id));
    await _prefs.removeRaw(_pwdHintKey(id));
    if (loadActiveId() == id) {
      await _setActiveId(profiles.isEmpty ? null : profiles.first.id);
    }
  }

  /// Switches the active profile and returns it (null when the list is empty).
  Future<ServerProfile?> switchTo(String id) async {
    final profiles = loadProfiles();
    final match = profiles.firstWhereOrNull((p) => p.id == id);
    if (match == null) return null;
    await _setActiveId(id);
    return match;
  }

  // Per-profile credentials ------------------------------------------------------

  static String _tokenKey(String id) => 'astrbot.token.$id';
  static String _usernameKey(String id) => 'astrbot.username.$id';
  static String _pwdHintKey(String id) => 'astrbot.changePwdHint.$id';

  /// Reads the token of [id], migrating the legacy single-token record on the
  /// fly so an existing installation keeps its session after the update.
  Future<String?> readToken(String id) async {
    final t = await _secure.read(_tokenKey(id));
    if (t != null && t.isNotEmpty) return t;
    // One-time migration of the pre-multi-profile token: claim it for this
    // profile, then destroy the legacy record so other profiles don't
    // inherit the same session.
    final legacyKey = 'astrbot.token';
    final legacy = await _secure.read(legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(_tokenKey(id), legacy);
      await _secure.delete(legacyKey);
      return legacy;
    }
    return null;
  }

  Future<void> writeToken(String id, String token) =>
      _secure.write(_tokenKey(id), token);

  Future<void> clearToken(String id) => _secure.delete(_tokenKey(id));

  String? readUsername(String id) {
    final v = _prefs.raw(_usernameKey(id));
    return v is String && v.isNotEmpty ? v : null;
  }

  Future<void> writeUsername(String id, String username) =>
      _prefs.setStringRaw(_usernameKey(id), username);

  bool readPwdHint(String id) => _prefs.raw(_pwdHintKey(id)) == true;

  Future<void> writePwdHint(String id, bool v) =>
      _prefs.setBoolRaw(_pwdHintKey(id), v);
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
