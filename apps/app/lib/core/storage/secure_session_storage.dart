import 'package:redream_app/core/storage/local_cipher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this.key);
  final String key;
  @override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null) {
      if (await secureStorage.read(key: key) == null) {
        await secureStorage.write(key: key, value: legacy);
        if (await secureStorage.read(key: key) != legacy) {
          throw StateError('Unable to migrate session to secure storage');
        }
      }
      await prefs.remove(key);
    }
  }

  @override
  Future<String?> accessToken() => secureStorage.read(key: key);
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String persistSessionString) =>
      secureStorage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => secureStorage.delete(key: key);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) =>
      secureStorage.read(key: 'pkce:$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      secureStorage.write(key: 'pkce:$key', value: value);
  @override
  Future<void> removeItem({required String key}) =>
      secureStorage.delete(key: 'pkce:$key');
}
