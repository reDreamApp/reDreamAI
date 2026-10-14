import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-bound key; preferences and audio files contain authenticated ciphertext.
const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);

class LocalCipher {
  LocalCipher(this._key);
  final SecretKey _key;
  static final _algorithm = AesGcm.with256bits();
  static const prefix = 'enc:v1:';

  static Future<LocalCipher> open() async {
    const name = 'redream-local-key-v1';
    var raw = await secureStorage.read(key: name);
    if (raw == null) {
      raw = base64Encode(
        await (await _algorithm.newSecretKey()).extractBytes(),
      );
      await secureStorage.write(key: name, value: raw);
      if (await secureStorage.read(key: name) != raw) {
        throw StateError('Unable to persist device encryption key');
      }
    }
    return LocalCipher(SecretKey(base64Decode(raw)));
  }

  Future<String> encrypt(List<int> bytes, String context) async {
    final box = await _algorithm.encrypt(
      bytes,
      secretKey: _key,
      aad: utf8.encode(context),
    );
    return '$prefix${base64Encode(box.concatenation())}';
  }

  Future<List<int>> decrypt(String value, String context) async {
    if (!value.startsWith(prefix)) {
      throw const FormatException('Invalid encrypted data');
    }
    final box = SecretBox.fromConcatenation(
      base64Decode(value.substring(prefix.length)),
      nonceLength: 12,
      macLength: 16,
    );
    return _algorithm.decrypt(box, secretKey: _key, aad: utf8.encode(context));
  }
}
