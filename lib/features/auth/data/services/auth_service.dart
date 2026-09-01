import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/core/error/auth_exception.dart';
import 'package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart';
import 'package:sitepulse_engineer/shared/models/engineer.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';

class AuthService {
  AuthService();

  Future<AuthSessionModel> login({
    required String companyCode,
    required String empCode,
    required String password,
    required bool rememberMe,
    required String deviceId,
  }) async {
    final client = await ApiClient.instance.dio;
    try {
      final response = await client.post('/api/v1/engineer/login', data: {
        'vendor_code': companyCode,
        'emp_code': empCode,
        'password': password,
        'remember_me': rememberMe,
        'device_id': deviceId,
      });

      if (response.statusCode == 200) {
        return AuthSessionModel(
          token: response.data['access_token'] ?? "",
          engineer: Engineer.fromJson(response.data['engineer']),
          mustChangePassword: response.data['must_change_password'] ?? false,
          expiresAtMs: response.data['expires_at_ms'],
          hasMpin: response.data['has_mpin'] ?? false,
          acceptedTerms: response.data['accepted_terms'] ?? false,
        );
      } else {
        throw AuthException(response.data['detail'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          final detail = data['error']?['message'] ?? data['detail'] ?? data['message'];
          if (detail != null) {
            throw AuthException(detail.toString());
          }
        }
      }
      throw AuthException('Login failed: ${e.message}');
    }
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = await ApiClient.instance.dio;
    try {
      final response = await client.post(
        '/api/v1/engineer/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        throw AuthException(response.data['detail'] ?? 'Password change failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          final detail = data['error']?['message'] ?? data['detail'] ?? data['message'];
          if (detail != null) {
            throw AuthException(detail.toString());
          }
        }
      }
      throw AuthException('Password change failed: ${e.message}');
    }
  }
  Future<void> setMpin(String token, String mpin) async {
    final client = await ApiClient.instance.dio;
    try {
      await client.post('/api/v1/engineer/set-mpin', data: {'mpin': mpin}, options: Options(headers: {'Authorization': 'Bearer $token'}));
    } on DioException catch (e) {
      throw AuthException(e.response?.data?['detail'] ?? 'Failed to set MPIN on server');
    }
  }

  Future<void> verifyMpin(String token, String mpin) async {
    final client = await ApiClient.instance.dio;
    try {
      await client.post('/api/v1/engineer/verify-mpin', data: {'mpin': mpin}, options: Options(headers: {'Authorization': 'Bearer $token'}));
    } on DioException catch (e) {
      throw AuthException(e.response?.data?['detail'] ?? 'Failed to verify MPIN on server');
    }
  }

  Future<void> sendMpinOtp(String vendorCode, String empCode, String email) async {
    final client = await ApiClient.instance.dio;
    try {
      await client.post('/api/v1/engineer/forgot-mpin', data: {
        'vendor_code': vendorCode,
        'emp_code': empCode,
        'email': email,
      });
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          final detail = data['error']?['message'] ?? data['detail'] ?? data['message'];
          if (detail != null) {
            throw AuthException(detail.toString());
          }
        }
      }
      throw AuthException('Failed to request MPIN OTP: ${e.message}');
    }
  }

  Future<String> verifyMpinOtp(String vendorCode, String empCode, String otp) async {
    final client = await ApiClient.instance.dio;
    try {
      final response = await client.post('/api/v1/engineer/verify-mpin-otp', data: {
        'vendor_code': vendorCode,
        'emp_code': empCode,
        'otp': otp,
      });
      return response.data['reset_token'] ?? '';
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          final detail = data['error']?['message'] ?? data['detail'] ?? data['message'];
          if (detail != null) {
            throw AuthException(detail.toString());
          }
        }
      }
      throw AuthException('Failed to verify OTP: ${e.message}');
    }
  }

  Future<void> setMpinWithToken(String resetToken, String mpin) async {
    final client = await ApiClient.instance.dio;
    try {
      await client.post('/api/v1/engineer/reset-mpin', data: {
        'reset_token': resetToken,
        'new_mpin': mpin,
      });
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          final detail = data['error']?['message'] ?? data['detail'] ?? data['message'];
          if (detail != null) {
            throw AuthException(detail.toString());
          }
        }
      }
      throw AuthException('Failed to reset MPIN with token: ${e.message}');
    }
  }
}
