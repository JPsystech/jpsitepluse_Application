import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";
import "package:sitepulse_engineer/core/network/api_client.dart";
import "package:sitepulse_engineer/shared/models/today_assignment.dart";
import "package:sitepulse_engineer/core/services/offline_punch_queue.dart";
import "package:sitepulse_engineer/core/error/error_handler.dart";
import "package:sitepulse_engineer/core/error/app_exception.dart";
import "package:sitepulse_engineer/core/error/error_type.dart";

class HistoryService {
  final ApiClient api;

  HistoryService({ApiClient? api}) : api = api ?? ApiClient.instance;

  Future<EngineerHistoryResponse> history(
      {required String token, String? month}) async {
    final qs = (month != null && month.trim().isNotEmpty)
        ? "?month=${Uri.encodeComponent(month.trim())}"
        : "";
    final cacheKey = "cached_timeline_v1_${month?.trim() ?? 'default'}";

    try {
      final client = await api.dio;
      final res = await client.get("/api/v1/engineer/history$qs");
      final json = res.data;
      
      if (json == null) {
        throw Exception("Invalid response from server");
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(json));

      final response = EngineerHistoryResponse.fromJson(json);
      return await _applyOfflinePunches(response);
    } catch (e) {
      final isOffline = ErrorHandler.isOfflineError(e);
      
      if (isOffline) {
        // Try to load from cache
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          final Map<String, dynamic> json = jsonDecode(cachedData);
          final response = EngineerHistoryResponse.fromJson(json);
          return await _applyOfflinePunches(response);
        } else {
          final response = EngineerHistoryResponse(startDate: "", endDate: "", items: []);
          final merged = await _applyOfflinePunches(response);
          if (merged.items.isNotEmpty) return merged;
          throw const AppException(
            userMessage: "Unable to connect to the server and no activity history is available.",
            type: AppErrorType.network,
          );
        }
      }
      rethrow;
    }
  }

  Future<EngineerHistoryResponse> _applyOfflinePunches(EngineerHistoryResponse response) async {
    final offlinePunches = await OfflinePunchQueue().list();
    if (offlinePunches.isEmpty) return response;

    final newItems = List<EngineerHistoryRow>.from(response.items);
    final prefs = await SharedPreferences.getInstance();
    final rawAssignments = prefs.getString("cached_today_assignments_v1");
    Map<String, dynamic>? assignmentsData;
    if (rawAssignments != null) {
      try {
        assignmentsData = jsonDecode(rawAssignments);
      } catch (_) {}
    }

    String getProjectName(String? pid) {
      if (pid == null || assignmentsData == null) return "Offline Project";
      final list = assignmentsData['assignments'];
      if (list is List) {
        for (var a in list) {
          if (a['project_id'] == pid) return a['project_name'] ?? "Offline Project";
        }
      }
      return "Offline Project";
    }

    String getSiteName(String? pid) {
      if (pid == null || assignmentsData == null) return "";
      final list = assignmentsData['assignments'];
      if (list is List) {
        for (var a in list) {
          if (a['project_id'] == pid) return a['site_name'] ?? "";
        }
      }
      return "";
    }

    String? currentActiveProjectId = assignmentsData?['active_project_id'] as String?;

    for (final punch in offlinePunches) {
      final punchTime = DateTime.tryParse(punch.clientPunchTimeIso) ?? DateTime.now();
      final dateStr = "${punchTime.year}-${punchTime.month.toString().padLeft(2, '0')}-${punchTime.day.toString().padLeft(2, '0')}";
      
      final isPunchIn = punch.type == OfflinePunchType.inPunch;
      final targetProjectId = punch.projectId ?? currentActiveProjectId;
      
      if (isPunchIn) {
        currentActiveProjectId = targetProjectId;
        // Create new punch in row
        newItems.insert(0, EngineerHistoryRow(
          workDate: dateStr,
          projectName: getProjectName(targetProjectId),
          siteName: getSiteName(targetProjectId),
          punchInTime: punchTime,
          punchOutTime: null,
          remarks: null,
          status: "PENDING_SYNC",
          punchInPhotoUrls: [],
          punchOutPhotoUrls: [],
          progressPhotoUrls: [],
        ));
      } else {
        currentActiveProjectId = null;
        // Find existing row to punch out of
        final idx = newItems.indexWhere((r) => r.workDate == dateStr && r.punchOutTime == null);
        if (idx != -1) {
          final old = newItems[idx];
          newItems[idx] = EngineerHistoryRow(
            workDate: old.workDate,
            projectName: old.projectName,
            siteName: old.siteName,
            punchInTime: old.punchInTime,
            punchOutTime: punchTime,
            remarks: punch.remarks,
            status: "PENDING_SYNC",
            punchInPhotoUrls: old.punchInPhotoUrls,
            punchOutPhotoUrls: old.punchOutPhotoUrls,
            progressPhotoUrls: old.progressPhotoUrls,
          );
        } else {
          // Unlikely: offline punch out without offline punch in, but maybe they punched in online
          // Try to find the latest active row
          final activeIdx = newItems.indexWhere((r) => r.punchOutTime == null);
          if (activeIdx != -1) {
            final old = newItems[activeIdx];
            newItems[activeIdx] = EngineerHistoryRow(
              workDate: old.workDate,
              projectName: old.projectName,
              siteName: old.siteName,
              punchInTime: old.punchInTime,
              punchOutTime: punchTime,
              remarks: punch.remarks,
              status: "PENDING_SYNC",
              punchInPhotoUrls: old.punchInPhotoUrls,
              punchOutPhotoUrls: old.punchOutPhotoUrls,
              progressPhotoUrls: old.progressPhotoUrls,
            );
          }
        }
      }
    }
    
    // Sort by punchInTime descending
    newItems.sort((a, b) => b.punchInTime.compareTo(a.punchInTime));

    return EngineerHistoryResponse(
      startDate: response.startDate,
      endDate: response.endDate,
      items: newItems,
    );
  }
}
