import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

/// Encrypted, app-private storage for offline data that is too large for the
/// platform keychain/keystore. The AES-256 key remains in secure storage.
class EncryptedFileStore {
  EncryptedFileStore._();

  static const _keyName = 'sitepulse_engineer_offline_data_key_v1';
  static const _directoryName = 'secure_offline_data';
  static const _storage = FlutterSecureStorage();

  static Future<String?> read(String name) async {
    final file = await _fileFor(name);
    if (!await file.exists()) return null;

    final payload = await file.readAsBytes();
    if (payload.length <= 12) {
      await file.delete();
      return null;
    }
    try {
      final key = await _key();
      final nonce = Uint8List.sublistView(payload, 0, 12);
      final cipherText = Uint8List.sublistView(payload, 12);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
        );
      return utf8.decode(cipher.process(cipherText));
    } catch (_) {
      // A restored file cannot be decrypted without its device-bound key.
      // Discard it and let the caller start with an empty offline cache.
      await file.delete();
      return null;
    }
  }

  static Future<void> write(String name, String value) async {
    final key = await _key();
    final nonce = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(value)));
    final payload = Uint8List(nonce.length + encrypted.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, nonce.length + encrypted.length, encrypted);

    final file = await _fileFor(name);
    // The foreground app and the tracking service run in separate isolates.
    // A shared ``.tmp`` name lets one isolate rename the other one's file,
    // which presents as a misleading "No such file or directory" error.
    final temp = File('${file.path}.${base64UrlEncode(_randomBytes(8))}.tmp');
    await temp.writeAsBytes(payload, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  static Future<void> delete(String name) async {
    final file = await _fileFor(name);
    if (await file.exists()) await file.delete();
  }

  static Future<File> _fileFor(String name) async {
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Invalid storage name');
    }
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}${Platform.pathSeparator}$_directoryName');
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$name.bin');
  }

  static Future<Uint8List> _key() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      final key = base64Url.decode(existing);
      if (key.length == 32) return Uint8List.fromList(key);
    }

    final key = _randomBytes(32);
    await _storage.write(key: _keyName, value: base64UrlEncode(key));
    return key;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
