import 'dart:convert';
import 'package:sitepulse_engineer/core/storage/safe_secure_storage.dart';
import 'package:sitepulse_engineer/shared/models/auth_session.dart';

class OfflineSessionCache {
  static const _key = 'sitepulse_engineer_offline_session';

  /// Saves the active session to persistent offline cache
  static Future<void> save(AuthSession session) async {
    final jsonStr = jsonEncode(session.toJson());
    await SafeSecureStorage.write(key: _key, value: jsonStr);
  }

  /// Restores the session from persistent offline cache
  static Future<AuthSession?> get() async {
    final jsonStr = await SafeSecureStorage.read(key: _key);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final jsonMap = jsonDecode(jsonStr);
      return AuthSession.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  /// Clears the offline session cache
  static Future<void> clear() async {
    await SafeSecureStorage.delete(key: _key);
  }
}
