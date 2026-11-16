import 'package:sitepulse_engineer/core/storage/safe_secure_storage.dart';

class CredentialStore {
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
    await SafeSecureStorage.write(key: _vendorCodeKey, value: vendorCode);
    await SafeSecureStorage.write(key: _empCodeKey, value: empCode);
    await SafeSecureStorage.write(key: _engineerNameKey, value: engineerName);
    await SafeSecureStorage.delete(key: _passwordKey);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final vendorCode = await SafeSecureStorage.read(key: _vendorCodeKey);
    final empCode = await SafeSecureStorage.read(key: _empCodeKey);
    final engineerName = await SafeSecureStorage.read(key: _engineerNameKey);

    // Remove the password left by previous app versions as soon as it is
    // encountered, while retaining the non-secret values used by MPIN reset.
    await SafeSecureStorage.delete(key: _passwordKey);

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
    await SafeSecureStorage.delete(key: _vendorCodeKey);
    await SafeSecureStorage.delete(key: _empCodeKey);
    await SafeSecureStorage.delete(key: _passwordKey);
    await SafeSecureStorage.delete(key: _engineerNameKey);
  }
}
