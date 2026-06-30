import "dart:convert";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:sitepulse_engineer/shared/models/auth_session.dart";

class SessionStore {
  static AuthSession? current;
  static final ValueNotifier<AuthSession?> notifier =
      ValueNotifier<AuthSession?>(null);

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
        return;
      }
    } catch (_) {}
    current = null;
    notifier.value = null;
  }

  static Future<void> set(AuthSession session) async {
    current = session;
    notifier.value = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    current = null;
    notifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
