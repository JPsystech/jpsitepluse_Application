import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";

import "../models/auth_session.dart";
import "../models/engineer.dart";
import "api_client.dart";

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

int? _tryJwtExpMs(String token) {
  final parts = token.split(".");
  if (parts.length < 2) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) {
      final exp = json["exp"];
      if (exp is num) {
        return exp.toInt() * 1000;
      }
    }
  } catch (_) {}
  return null;
}

class AuthService {
  final ApiClient api;

  AuthService({ApiClient? api}) : api = api ?? ApiClient();

  Future<AuthSession> login({required String empCode, required String password, bool rememberMe = false}) async {
    final uri = await api.url("/api/v1/engineer/login");
    final payload = {"emp_code": empCode, "password": password, "remember_me": rememberMe};
    _log("[AuthService] Login URL: $uri");
    final json = await api.postJson(
      uri,
      headers: {HttpHeaders.contentTypeHeader: "application/json"},
      body: jsonEncode(payload),
    );

    final token = (json?["access_token"] as String?) ?? "";
    final engineerJson = json?["engineer"] as Map<String, dynamic>?;
    final mustChangePassword = (json?["must_change_password"] as bool?) ?? false;
    if (token.isEmpty || engineerJson == null) {
      throw ApiException("Invalid response from server");
    }

    return AuthSession(
      token: token,
      engineer: Engineer.fromJson(engineerJson),
      mustChangePassword: mustChangePassword,
      expiresAtMs: _tryJwtExpMs(token),
    );
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = await api.url("/api/v1/engineer/change-password");
    final payload = {"current_password": currentPassword, "new_password": newPassword};
    _log("[AuthService] Change password URL: $uri");
    await api.postJson(
      uri,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        HttpHeaders.authorizationHeader: "Bearer $token",
      },
      body: jsonEncode(payload),
    );
  }
}
