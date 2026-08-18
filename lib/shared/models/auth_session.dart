import "engineer.dart";

class AuthSession {
  final String token;
  final Engineer engineer;
  final bool mustChangePassword;
  final int? expiresAtMs;
  final bool hasMpin;
  final bool acceptedTerms;

  AuthSession({
    required this.token,
    required this.engineer,
    required this.mustChangePassword,
    required this.expiresAtMs,
    this.hasMpin = false,
    this.acceptedTerms = false,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: (json["token"] as String?) ?? "",
      engineer: Engineer.fromJson(
          (json["engineer"] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{}),
      mustChangePassword: (json["must_change_password"] as bool?) ?? false,
      expiresAtMs: (json["expires_at_ms"] as num?)?.toInt(),
      hasMpin: (json["has_mpin"] as bool?) ?? false,
      acceptedTerms: (json["accepted_terms"] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "token": token,
      "engineer": engineer.toJson(),
      "must_change_password": mustChangePassword,
      "expires_at_ms": expiresAtMs,
      "has_mpin": hasMpin,
      "accepted_terms": acceptedTerms,
    };
  }
}

