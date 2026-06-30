import 'package:sitepulse_engineer/shared/models/auth_session.dart';

class AuthSessionModel extends AuthSession {
  AuthSessionModel({
    required super.token,
    required super.engineer,
    required super.mustChangePassword,
    required super.expiresAtMs,
  });
}
