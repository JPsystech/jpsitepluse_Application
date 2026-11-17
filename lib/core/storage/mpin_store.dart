import "dart:convert";
import "dart:math";
import "dart:typed_data";

import "package:pointycastle/export.dart";
import "package:sitepulse_engineer/core/storage/safe_secure_storage.dart";

class MpinStore {
  static const _legacyMpinKey = "sitepulse_engineer_mpin";
  static const _mpinHashKey = "sitepulse_engineer_mpin_hash_v1";
  static const _mpinSaltKey = "sitepulse_engineer_mpin_salt_v1";
  static const _attemptStateKey = "sitepulse_engineer_mpin_attempt_state_v1";
  static const _maximumFailures = 5;
  static const _lockout = Duration(minutes: 5);

  /// Checks if an MPIN is currently saved
  static Future<bool> hasMpin() async {
    final hash = await SafeSecureStorage.read(key: _mpinHashKey);
    if (hash != null && hash.isNotEmpty) return true;
    final legacy = await SafeSecureStorage.read(key: _legacyMpinKey);
    return legacy != null && legacy.trim().isNotEmpty;
  }

  /// Verifies if the provided MPIN matches the saved one
  static Future<bool> verifyMpin(String mpin) async {
    if (await isLocked()) return false;

    final savedHash = await SafeSecureStorage.read(key: _mpinHashKey);
    final savedSalt = await SafeSecureStorage.read(key: _mpinSaltKey);
    bool matches = false;
    if (savedHash != null && savedSalt != null) {
      matches = _constantTimeEquals(savedHash, _hash(mpin.trim(), savedSalt));
    } else {
      // Migrate the legacy plaintext MPIN only after a successful check.
      final legacy = await SafeSecureStorage.read(key: _legacyMpinKey);
      matches = legacy != null && _constantTimeEquals(legacy, mpin.trim());
      if (matches) await setMpin(mpin);
    }

    if (matches) {
      await _clearFailures();
    } else {
      await recordFailure();
    }
    return matches;
  }

  static Future<bool> isLocked() async {
    final raw = await SafeSecureStorage.read(key: _attemptStateKey);
    if (raw == null) return false;
    try {
      final state = jsonDecode(raw) as Map<String, dynamic>;
      final lockedUntil = state['locked_until_ms'] as int?;
      return lockedUntil != null &&
          DateTime.now().millisecondsSinceEpoch < lockedUntil;
    } catch (_) {
      await SafeSecureStorage.delete(key: _attemptStateKey);
      return false;
    }
  }

  static Future<void> recordFailure() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var attempts = 0;
    final raw = await SafeSecureStorage.read(key: _attemptStateKey);
    if (raw != null) {
      try {
        attempts = (jsonDecode(raw) as Map<String, dynamic>)['attempts'] as int? ?? 0;
      } catch (_) {}
    }
    attempts++;
    final lockedUntil = attempts >= _maximumFailures
        ? now + _lockout.inMilliseconds
        : 0;
    await SafeSecureStorage.write(
      key: _attemptStateKey,
      value: jsonEncode({
        'attempts': attempts >= _maximumFailures ? 0 : attempts,
        'locked_until_ms': lockedUntil,
      }),
    );
  }

  /// Securely saves the new MPIN
  static Future<void> setMpin(String mpin) async {
    final random = Random.secure();
    final salt = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    await SafeSecureStorage.write(key: _mpinSaltKey, value: salt);
    await SafeSecureStorage.write(key: _mpinHashKey, value: _hash(mpin.trim(), salt));
    await SafeSecureStorage.delete(key: _legacyMpinKey);
    await _clearFailures();
  }

  /// Deletes the MPIN from secure storage
  static Future<void> clearMpin() async {
    await SafeSecureStorage.delete(key: _legacyMpinKey);
    await SafeSecureStorage.delete(key: _mpinHashKey);
    await SafeSecureStorage.delete(key: _mpinSaltKey);
    await _clearFailures();
  }

  static Future<void> _clearFailures() =>
      SafeSecureStorage.delete(key: _attemptStateKey);

  static String _hash(String mpin, String salt) {
    final digest = SHA256Digest().process(
      Uint8List.fromList(utf8.encode('$salt:$mpin')),
    );
    return base64UrlEncode(digest);
  }

  static bool _constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    if (a.length != b.length) return false;
    var difference = 0;
    for (var index = 0; index < a.length; index++) {
      difference |= a[index] ^ b[index];
    }
    return difference == 0;
  }
}
