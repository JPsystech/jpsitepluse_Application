import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';

class HomeService {
  Future<TodayAssignmentResponseModel> getTodayAssignments() async {
    const cacheKey = "cached_today_assignments_v1";
    final client = await ApiClient.instance.dio;

    try {
      final response = await client.get('/api/v1/engineer/today-assignments');

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        // Use a generic key, but if we wanted to be perfectly safe, we'd clear it on logout.
        // For now, let's just save it.
        await prefs.setString(cacheKey, jsonEncode(response.data));
        return TodayAssignmentResponseModel.fromJson(response.data);
      } else {
        throw Exception(
            response.data['detail'] ?? 'Failed to load assignments');
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      
      // If we are getting a 401 Unauthenticated, we shouldn't load from cache.
      if (e is DioException && e.response?.statusCode == 401) {
        rethrow;
      }
      
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return TodayAssignmentResponseModel.fromJson(decoded);
        }
      }
      rethrow;
    }
  }
}
