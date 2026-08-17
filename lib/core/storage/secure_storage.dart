/// Secret persistence for the AstrBot bearer token.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _kToken = 'astrbot.token';
  final FlutterSecureStorage _storage;

  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<void> clearToken() => _storage.delete(key: _kToken);

  // Generic access used by ProfileStore for per-profile tokens ---------------
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
}
