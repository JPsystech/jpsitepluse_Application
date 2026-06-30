import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart';
import 'package:sitepulse_engineer/shared/models/engineer.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';

class AuthService {
  AuthService();

  Future<AuthSessionModel> login({
    required String companyCode,
    required String empCode,
    required String password,
  }) async {
    final client = await ApiClient.instance.dio;
    final response = await client.post('/api/v1/engineer/login', data: {
      'company_code': companyCode,
      'emp_code': empCode,
      'password': password,
    });

    if (response.statusCode == 200) {
      return AuthSessionModel(
        token: response.data['access_token'] ?? "",
        engineer: Engineer.fromJson(response.data['engineer']),
        mustChangePassword: response.data['must_change_password'] ?? false,
        expiresAtMs: response.data['expires_at_ms'] ?? 0,
      );
    } else {
      throw Exception(response.data['detail'] ?? 'Login failed');
    }
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = await ApiClient.instance.dio;
    final response = await client.post(
      '/api/v1/engineer/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['detail'] ?? 'Password change failed');
    }
  }
}
