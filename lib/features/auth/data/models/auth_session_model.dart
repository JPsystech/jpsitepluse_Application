import 'package:sitepulse_engineer/shared/models/auth_session.dart';

class AuthSessionModel extends AuthSession {
  @override
  final bool acceptedTerms;

  AuthSessionModel({
    required super.token,
    required super.engineer,
    required super.mustChangePassword,
    required super.expiresAtMs,
    super.hasMpin = false,
    this.acceptedTerms = false,
  }) : super(acceptedTerms: acceptedTerms);
}

