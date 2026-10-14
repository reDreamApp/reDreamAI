import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redream_app/core/storage/local_cipher.dart';

/// Ciphertext may persist offline; decoded playback files live only in temp.
class SecureAudioCache {
  static Future<String> _hash(String value) async => (await Sha256().hash(
    utf8.encode(value),
  )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  static Future<File> file(
    String userId,
    int dreamId,
    String language,
    String rewrite,
  ) async {
    final dir = await getApplicationSupportDirectory();
    final owner = await _hash(userId);
    final content = await _hash(rewrite);
    return File(
      '${dir.path}/secure_rehearsal/$owner/${dreamId}_${language}_$content.enc',
    );
  }

  static Future<void> clearUser(String userId) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(
      '${dir.path}/secure_rehearsal/${await _hash(userId)}',
    );
    if (folder.existsSync()) await folder.delete(recursive: true);
  }

  static Future<void> removeLegacyPlaintext() async {
    final documents = await getApplicationDocumentsDirectory();
    final legacy = Directory('${documents.path}/rehearsal_audio');
    if (legacy.existsSync()) await legacy.delete(recursive: true);
    final temporary = await getTemporaryDirectory();
    final playback = Directory('${temporary.path}/redream_playback');
    if (playback.existsSync()) await playback.delete(recursive: true);
  }

  static Future<void> save(File file, List<int> bytes) async {
    final cipher = await LocalCipher.open();
    final encrypted = await cipher.encrypt(
      bytes,
      file.path.split('/secure_rehearsal/').last,
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(encrypted, flush: true);
  }

  static Future<File> decodeForPlayback(File file) async {
    final cipher = await LocalCipher.open();
    final bytes = await cipher.decrypt(
      await file.readAsString(),
      file.path.split('/secure_rehearsal/').last,
    );
    final temp = await getTemporaryDirectory();
    final folder = await Directory(
      '${temp.path}/redream_playback',
    ).createTemp();
    final decoded = File('${folder.path}/audio.mp3');
    await decoded.writeAsBytes(bytes, flush: true);
    return decoded;
  }
}
