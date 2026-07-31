import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  static const _storage = FlutterSecureStorage();
  
  static const _vendorCodeKey = "sitepulse_engineer_vendor_code";
  static const _empCodeKey = "sitepulse_engineer_emp_code";
  static const _passwordKey = "sitepulse_engineer_password";
  static const _engineerNameKey = "sitepulse_engineer_name";

  static Future<void> saveCredentials({
    required String vendorCode,
    required String empCode,
    required String password,
    required String engineerName,
  }) async {
    await _storage.write(key: _vendorCodeKey, value: vendorCode);
    await _storage.write(key: _empCodeKey, value: empCode);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _engineerNameKey, value: engineerName);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final vendorCode = await _storage.read(key: _vendorCodeKey);
    final empCode = await _storage.read(key: _empCodeKey);
    final password = await _storage.read(key: _passwordKey);
    final engineerName = await _storage.read(key: _engineerNameKey);

    if (vendorCode != null && empCode != null && password != null) {
      return {
        'vendorCode': vendorCode,
        'empCode': empCode,
        'password': password,
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
