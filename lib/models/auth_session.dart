import "engineer.dart";

class AuthSession {
  final String token;
  final Engineer engineer;
  final bool mustChangePassword;
  final int? expiresAtMs;

  AuthSession({required this.token, required this.engineer, required this.mustChangePassword, required this.expiresAtMs});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: (json["token"] as String?) ?? "",
      engineer: Engineer.fromJson((json["engineer"] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{}),
      mustChangePassword: (json["must_change_password"] as bool?) ?? false,
      expiresAtMs: (json["expires_at_ms"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "token": token,
      "engineer": engineer.toJson(),
      "must_change_password": mustChangePassword,
      "expires_at_ms": expiresAtMs,
    };
  }
}
