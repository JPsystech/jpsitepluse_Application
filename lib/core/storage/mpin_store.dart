import "package:flutter_secure_storage/flutter_secure_storage.dart";

class MpinStore {
  static const _storage = FlutterSecureStorage();
  static const _mpinKey = "sitepulse_engineer_mpin";

  /// Checks if an MPIN is currently saved
  static Future<bool> hasMpin() async {
    final mpin = await _storage.read(key: _mpinKey);
    return mpin != null && mpin.trim().isNotEmpty;
  }

  /// Verifies if the provided MPIN matches the saved one
  static Future<bool> verifyMpin(String mpin) async {
    final savedMpin = await _storage.read(key: _mpinKey);
    if (savedMpin == null) return false;
    return savedMpin == mpin.trim();
  }

  /// Securely saves the new MPIN
  static Future<void> setMpin(String mpin) async {
    await _storage.write(key: _mpinKey, value: mpin.trim());
  }

  /// Deletes the MPIN from secure storage
  static Future<void> clearMpin() async {
    await _storage.delete(key: _mpinKey);
  }
}
