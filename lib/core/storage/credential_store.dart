import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  static const _storage = FlutterSecureStorage();
  
  static const _vendorCodeKey = "sitepulse_engineer_vendor_code";
  static const _empCodeKey = "sitepulse_engineer_emp_code";
  // Legacy key retained only so it can be removed from devices upgraded from
  // older versions. Passwords must never be persisted for convenience login.
  static const _passwordKey = "sitepulse_engineer_password";
  static const _engineerNameKey = "sitepulse_engineer_name";

  static Future<void> saveCredentials({
    required String vendorCode,
    required String empCode,
    required String engineerName,
  }) async {
    await _storage.write(key: _vendorCodeKey, value: vendorCode);
    await _storage.write(key: _empCodeKey, value: empCode);
    await _storage.write(key: _engineerNameKey, value: engineerName);
    await _storage.delete(key: _passwordKey);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final vendorCode = await _storage.read(key: _vendorCodeKey);
    final empCode = await _storage.read(key: _empCodeKey);
    final engineerName = await _storage.read(key: _engineerNameKey);

    // Remove the password left by previous app versions as soon as it is
    // encountered, while retaining the non-secret values used by MPIN reset.
    await _storage.delete(key: _passwordKey);

    if (vendorCode != null && empCode != null) {
      return {
        'vendorCode': vendorCode,
        'empCode': empCode,
        'engineerName': engineerName ?? 'Engineer',
      };
    }
    return null;
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _vendorCodeKey);
    await _storage.delete(key: _empCodeKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _engineerNameKey);
  }
}
