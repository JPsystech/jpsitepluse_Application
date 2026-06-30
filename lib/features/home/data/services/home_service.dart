import 'dart:convert';
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
        await prefs.setString(cacheKey, jsonEncode(response.data));
        return TodayAssignmentResponseModel.fromJson(response.data);
      } else {
        throw Exception(
            response.data['detail'] ?? 'Failed to load assignments');
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
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
