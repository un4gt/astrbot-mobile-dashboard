/// SharedPreferences keys + helper for non-secret persisted values.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefKeys {
  static const baseUrl = 'astrbot.baseUrl';
  static const themeMode = 'astrbot.themeMode'; // 'light' | 'dark' | 'system'
  static const locale = 'astrbot.locale'; // 'zh-CN' | 'en-US'
  static const username = 'astrbot.username';
  static const changePwdHint = 'astrbot.changePwdHint';
  static const localDebug = 'astrbot.localDebug'; // built-in mock data, no server
  static const autoCheckUpdate = 'astrbot.autoCheckUpdate'; // self-update check
  static const profilesJson = 'astrbot.profiles'; // multi-server list
  static const activeProfileId = 'astrbot.activeProfileId';
}

class Prefs {
  Prefs(this._sp);
  final SharedPreferences _sp;

  static Future<Prefs> create() async {
    return Prefs(await SharedPreferences.getInstance());
  }

  // Server URL ---------------------------------------------------------------
  String? get baseUrl {
    final v = _sp.getString(PrefKeys.baseUrl);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setBaseUrl(String url) async {
    // strip trailing slash so callers can append /api/...
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _sp.setString(PrefKeys.baseUrl, cleaned);
  }

  Future<void> clearBaseUrl() async => _sp.remove(PrefKeys.baseUrl);

  // Theme --------------------------------------------------------------------
  ThemeMode get themeMode {
    switch (_sp.getString(PrefKeys.themeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final s = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _sp.setString(PrefKeys.themeMode, s);
  }

  // Locale -------------------------------------------------------------------
  /// Returns IETF tag like 'zh-CN' / 'en-US', or null for system default.
  String? get localeTag => _sp.getString(PrefKeys.locale);
  Future<void> setLocaleTag(String? tag) async {
    if (tag == null) {
      await _sp.remove(PrefKeys.locale);
    } else {
      await _sp.setString(PrefKeys.locale, tag);
    }
  }

  // User metadata (non-secret) ----------------------------------------------
  String? get username => _sp.getString(PrefKeys.username);
  Future<void> setUsername(String? u) async {
    if (u == null) {
      await _sp.remove(PrefKeys.username);
    } else {
      await _sp.setString(PrefKeys.username, u);
    }
  }

  bool get changePwdHint => _sp.getBool(PrefKeys.changePwdHint) ?? false;
  Future<void> setChangePwdHint(bool v) async =>
      _sp.setBool(PrefKeys.changePwdHint, v);

  // Local debug (mock data, no server) ----------------------------------------
  bool get localDebug => _sp.getBool(PrefKeys.localDebug) ?? false;
  Future<void> setLocalDebug(bool v) async =>
      _sp.setBool(PrefKeys.localDebug, v);

  // App self-update ------------------------------------------------------------
  bool get autoCheckUpdate => _sp.getBool(PrefKeys.autoCheckUpdate) ?? true;
  Future<void> setAutoCheckUpdate(bool v) async =>
      _sp.setBool(PrefKeys.autoCheckUpdate, v);

  // Raw typed access for callers that own their own key scheme
  // (e.g. ProfileStore's per-profile records) -------------------------------
  dynamic raw(String key) => _sp.get(key);
  Future<void> setStringRaw(String key, String v) => _sp.setString(key, v);
  Future<void> setBoolRaw(String key, bool v) => _sp.setBool(key, v);
  Future<void> removeRaw(String key) => _sp.remove(key);
}
