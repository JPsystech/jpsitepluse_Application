import "dart:convert";
import 'package:sitepulse_engineer/core/network/unauthorized_interceptor.dart';
import 'package:sitepulse_engineer/core/services/notification_service.dart';

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:uuid/uuid.dart";

import "package:sitepulse_engineer/shared/models/auth_session.dart";

class SessionStore {
  static AuthSession? current;
  static final ValueNotifier<AuthSession?> notifier =
      ValueNotifier<AuthSession?>(null);
  static bool sessionExpired = false;
  static String? expiredReason;

  static const String _key = "sitepulse_engineer_session";

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      current = null;
      notifier.value = null;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final session = AuthSession.fromJson(decoded);
        if (session.token.trim().isEmpty) {
          current = null;
          notifier.value = null;
          await prefs.remove(_key);
          return;
        }
        final expMs = session.expiresAtMs;
        if (expMs != null && DateTime.now().millisecondsSinceEpoch >= expMs) {
          current = null;
          notifier.value = null;
          await prefs.remove(_key);
          return;
        }
        current = session;
        notifier.value = session;
        NotificationService.instance.syncToken();
        return;
      }
    } catch (_) {}
    current = null;
    notifier.value = null;
  }

  static Future<void> set(AuthSession session) async {
    sessionExpired = false;
    expiredReason = null;
    UnauthorizedInterceptor.reset();

    current = session;
    notifier.value = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
    NotificationService.instance.syncToken();
  }

  static Future<void> clear() async {
    await NotificationService.instance.unregisterToken();
    current = null;
    notifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> expireSession([String? reason]) async {
    sessionExpired = true;
    expiredReason = reason;
    await clear();
  }

  static Future<String> getDeviceId() async {
    const storage = FlutterSecureStorage();
    const deviceIdKey = "sitepulse_engineer_device_id";
    String? deviceId = await storage.read(key: deviceIdKey);
    
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await storage.write(key: deviceIdKey, value: deviceId);
    }
    return deviceId;
  }
}
