import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Short-lived tracking token kept separately from the UI session so a
/// restarted background isolate can continue an active duty shift.
class DutySessionStore {
  DutySessionStore._();

  static const _key = 'sitepulse_engineer_active_duty_token_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static String? _token;

  static String? get token => _token;

  static Future<void> save(String? token) async {
    final value = token?.trim();
    _token = value?.isNotEmpty == true ? value : null;
    if (_token == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: _token);
    }
  }

  static Future<String?> load() async {
    final value = await _storage.read(key: _key);
    _token = value?.trim().isNotEmpty == true ? value!.trim() : null;
    return _token;
  }

  static Future<void> clear() => save(null);
}
