import 'package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart';
import 'package:sitepulse_engineer/features/auth/data/services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<AuthSessionModel> login({
    required String companyCode,
    required String empCode,
    required String password,
  }) async {
    return await _authService.login(
      companyCode: companyCode,
      empCode: empCode,
      password: password,
    );
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _authService.changePassword(
      token: token,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
