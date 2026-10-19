import "dart:convert";
import 'package:sitepulse_engineer/core/network/unauthorized_interceptor.dart';
import 'package:sitepulse_engineer/core/services/notification_service.dart';
import 'package:sitepulse_engineer/core/services/live_location_tracking_service.dart';

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:uuid/uuid.dart";

import "package:sitepulse_engineer/shared/models/auth_session.dart";
import "package:sitepulse_engineer/shared/models/engineer.dart";
import "package:sitepulse_engineer/core/network/api_client.dart";

class SessionStore {
  static AuthSession? current;
  static final ValueNotifier<AuthSession?> notifier =
      ValueNotifier<AuthSession?>(null);
  static bool sessionExpired = false;
  static String? expiredReason;

  static const String _key = "sitepulse_engineer_session";
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> load() async {
    // 1. Try reading from FlutterSecureStorage
    String? raw = await _secureStorage.read(key: _key);

    // 2. Migration fallback: check legacy SharedPreferences if not in secure storage
    if (raw == null || raw.trim().isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_key);
      if (raw != null && raw.trim().isNotEmpty) {
        // Migration: Move legacy session to secure storage and delete from SharedPreferences
        await _secureStorage.write(key: _key, value: raw);
        await prefs.remove(_key);
      }
    }

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
          await _clearStorage();
          return;
        }
        final expMs = session.expiresAtMs;
        if (expMs != null && DateTime.now().millisecondsSinceEpoch >= expMs) {
          await _clearStorage();
          return;
        }
        current = session;
        notifier.value = session;
        NotificationService.instance.syncToken();
        return;
      }
    } catch (_) {}

    await _clearStorage();
  }

  static Future<void> set(AuthSession session) async {
    sessionExpired = false;
    expiredReason = null;
    UnauthorizedInterceptor.reset();

    current = session;
    notifier.value = session;

    // Save token & session to secure storage
    await _secureStorage.write(key: _key, value: jsonEncode(session.toJson()));

    // Clean up legacy SharedPreferences key if present
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);

    NotificationService.instance.syncToken();
  }

  static Future<void> clear() async {
    await LiveLocationTrackingService.instance.stopDutyTracking();
    await NotificationService.instance.cancelActiveShiftNotification();
    await NotificationService.instance.unregisterToken();
    await _clearStorage();
  }

  static Future<void> _clearStorage() async {
    current = null;
    notifier.value = null;
    await _secureStorage.delete(key: _key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> expireSession([String? reason]) async {
    sessionExpired = true;
    expiredReason = reason;
    await clear();
  }

  static Future<Engineer?> syncProfile() async {
    try {
      final session = current;
      if (session == null || session.token.trim().isEmpty) return null;
      final client = await ApiClient.instance.dio;
      final response = await client.get('/api/v1/engineer/me');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final updatedEngineer = Engineer.fromJson(response.data as Map<String, dynamic>);
        final updatedSession = session.copyWith(engineer: updatedEngineer);
        await set(updatedSession);
        return updatedEngineer;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to sync engineer profile: $e');
      }
    }
    return current?.engineer;
  }

  static Future<String> getDeviceId() async {
    const deviceIdKey = "sitepulse_engineer_device_id";
    String? deviceId = await _secureStorage.read(key: deviceIdKey);
    
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await _secureStorage.write(key: deviceIdKey, value: deviceId);
    }
    return deviceId;
  }
}
