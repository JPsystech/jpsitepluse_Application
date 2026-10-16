import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/shared/models/engineer.dart';
import '../models/onboarding_status_model.dart';

class OnboardingService {
  final ApiClient api;

  OnboardingService({ApiClient? api}) : api = api ?? ApiClient.instance;

  Future<OnboardingStatusModel> getOnboardingStatus({String? token}) async {
    final client = await api.dio;
    final options = (token != null && token.isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $token'})
        : null;

    final response = await client.get(
      '/api/v1/engineer/onboarding-status',
      options: options,
    );

    if (response.data is Map<String, dynamic>) {
      return OnboardingStatusModel.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Invalid onboarding status response from server');
  }

  Future<Engineer> updateProfile({
    String? token,
    required Map<String, dynamic> data,
  }) async {
    final client = await api.dio;
    final options = (token != null && token.isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $token'})
        : null;

    final response = await client.patch(
      '/api/v1/engineer/profile',
      data: data,
      options: options,
    );

    if (response.data is Map<String, dynamic>) {
      final updated = Engineer.fromJson(response.data as Map<String, dynamic>);
      final currentSession = SessionStore.current;
      if (currentSession != null) {
        await SessionStore.set(currentSession.copyWith(engineer: updated));
      }
      return updated;
    }
    throw Exception('Failed to update profile details');
  }
}
