// Tests for the multi-server ProfileStore: list/active persistence, CRUD,
// per-profile credential isolation, and legacy single-server migration.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:astrbot_mobile/core/storage/prefs.dart';
import 'package:astrbot_mobile/core/storage/profile_store.dart';
import 'package:astrbot_mobile/core/storage/secure_storage.dart';

void main() {
  late _FakeSecure secure;
  late ProfileStore store;
  late Prefs prefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    secure = _FakeSecure();
    prefs = Prefs(await SharedPreferences.getInstance());
    store = ProfileStore(prefs, secure);
  });

  test('upsert creates, activates, and persists across reloads', () async {
    await store.upsert(name: 'home', baseUrl: 'http://192.168.1.10:6185/');
    await store.upsert(name: 'vps', baseUrl: 'https://bot.example.com');

    final profiles = store.loadProfiles();
    expect(profiles.length, 2);
    expect(profiles.first.baseUrl, 'http://192.168.1.10:6185'); // slash stripped
    expect(store.loadActiveId(), profiles.last.id); // latest became active
    expect(store.activeProfile()!.name, 'vps');
  });

  test('switchTo changes the active profile', () async {
    final a = await store.upsert(name: 'a', baseUrl: 'http://a/');
    await store.upsert(name: 'b', baseUrl: 'http://b/');
    final back = await store.switchTo(a.id);
    expect(back!.name, 'a');
    expect(store.loadActiveId(), a.id);
    expect(store.activeProfile()!.name, 'a');
  });

  test('remove deletes credentials and falls back to first profile', () async {
    final a = await store.upsert(name: 'a', baseUrl: 'http://a/');
    final b = await store.upsert(name: 'b', baseUrl: 'http://b/');
    await store.writeToken(b.id, 'tok-b');
    await store.writeUsername(b.id, 'user-b');

    await store.remove(b.id);

    expect(store.loadProfiles().length, 1);
    expect(await store.readToken(b.id), isNull);
    expect(store.readUsername(b.id), isNull);
    expect(store.loadActiveId(), a.id);
  });

  test('tokens are isolated per profile', () async {
    final a = await store.upsert(name: 'a', baseUrl: 'http://a/');
    final b = await store.upsert(name: 'b', baseUrl: 'http://b/');
    await store.writeToken(a.id, 'tok-a');
    await store.writeToken(b.id, 'tok-b');
    expect(await store.readToken(a.id), 'tok-a');
    expect(await store.readToken(b.id), 'tok-b');
    await store.clearToken(a.id);
    expect(await store.readToken(a.id), isNull);
    expect(await store.readToken(b.id), 'tok-b');
  });

  test('legacy single token migrates into the active profile once', () async {
    await secure.writeToken('legacy-token'); // old key
    final a = await store.upsert(name: 'a', baseUrl: 'http://a/');
    expect(await store.readToken(a.id), 'legacy-token');
    // Old record consumed; a new profile does not inherit it.
    final b = await store.upsert(name: 'b', baseUrl: 'http://b/');
    expect(await store.readToken(b.id), isNull);
  });

  test('corrupt profile JSON degrades to empty list', () async {
    await prefs.setStringRaw(PrefKeys.profilesJson, '{not json');
    expect(store.loadProfiles(), isEmpty);
  });
}

class _FakeSecure implements SecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> readToken() async => _map['astrbot.token'];
  @override
  Future<void> writeToken(String t) async => _map['astrbot.token'] = t;
  @override
  Future<void> clearToken() async => _map.remove('astrbot.token');
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<void> delete(String key) async => _map.remove(key);
}
