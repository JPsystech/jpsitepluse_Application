import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/core/services/offline_punch_queue.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';
import 'package:sitepulse_engineer/core/error/app_exception.dart';
import 'package:sitepulse_engineer/core/error/error_type.dart';

class HomeService {
  Future<TodayAssignmentResponseModel> getTodayAssignments() async {
    const cacheKey = "cached_today_assignments_v1";
    final client = await ApiClient.instance.dio;

    try {
      final response = await client.get('/api/v1/engineer/today-assignments');

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(response.data));
        final mergedData = await _applyOfflinePunches(response.data);
        return TodayAssignmentResponseModel.fromJson(mergedData);
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
          final mergedData = await _applyOfflinePunches(decoded);
          return TodayAssignmentResponseModel.fromJson(mergedData);
        }
      }
      
      final isOffline = ErrorHandler.isOfflineError(e);
      
      if (isOffline) {
        throw const AppException(
          userMessage: "Unable to connect to the server and no dashboard data is available.",
          type: AppErrorType.network,
        );
      }
      
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _applyOfflinePunches(Map<String, dynamic> data) async {
    final offlinePunches = await OfflinePunchQueue().list();
    if (offlinePunches.isEmpty) return data;
    
    String? currentActiveProjectId = data['active_project_id'] as String?;
    
    for (final punch in offlinePunches) {
      final isPunchIn = punch.type == OfflinePunchType.inPunch;
      final targetProjectId = punch.projectId ?? currentActiveProjectId;
      
      if (isPunchIn) {
        currentActiveProjectId = targetProjectId;
        data['active_project_id'] = targetProjectId;
        data['active_attendance_log_id'] = "offline_";
        if (data['assignments'] is List && targetProjectId != null) {
           for (var a in data['assignments']) {
              if (a['project_id'] == targetProjectId) {
                 a['today_punch_in_time'] = punch.clientPunchTimeIso;
                 a['today_status'] = "PUNCHED_IN";
                 a.remove('today_punch_out_time');
              }
           }
        }
      } else {
        data['active_project_id'] = null;
        data['active_attendance_log_id'] = null;
        currentActiveProjectId = null;
        if (data['assignments'] is List && targetProjectId != null) {
           for (var a in data['assignments']) {
              if (a['project_id'] == targetProjectId) {
                 a['today_punch_out_time'] = punch.clientPunchTimeIso;
                 a['today_status'] = "PUNCHED_OUT";
              }
           }
        }
      }
    }
    return data;
  }
}
