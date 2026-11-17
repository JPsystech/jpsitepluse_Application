import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sitepulse_engineer/core/storage/safe_secure_storage.dart';

/// Short-lived tracking token kept separately from the UI session so a
/// restarted background isolate can continue an active duty shift.
class DutySessionStore {
  DutySessionStore._();

  static const _key = 'sitepulse_engineer_active_duty_token_v1';
  static const _aOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const _iOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  static String? _token;

  static String? get token => _token;

  static Future<void> save(String? token) async {
    final value = token?.trim();
    _token = value?.isNotEmpty == true ? value : null;
    if (_token == null) {
      await SafeSecureStorage.delete(
        key: _key,
        iOptions: _iOptions,
        aOptions: _aOptions,
      );
    } else {
      await SafeSecureStorage.write(
        key: _key,
        value: _token,
        iOptions: _iOptions,
        aOptions: _aOptions,
      );
    }
  }

  static Future<String?> load() async {
    final value = await SafeSecureStorage.read(
      key: _key,
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
    _token = value?.trim().isNotEmpty == true ? value!.trim() : null;
    return _token;
  }

  static Future<void> clear() => save(null);
}
