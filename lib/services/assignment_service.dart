import "dart:io";
import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "../models/today_assignment.dart";
import "api_client.dart";

class AssignmentService {
  final ApiClient api;

  AssignmentService({ApiClient? api}) : api = api ?? ApiClient();

  Future<TodayAssignmentResponse> todayAssignment({required String token}) async {
    const cacheKey = "cached_today_assignments_v1";
    final uri = await api.url("/api/v1/engineer/today-assignments");
    try {
      final json = await api.getJson(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
      if (json == null) {
        throw ApiException("Invalid response from server");
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(json));
      return TodayAssignmentResponse.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            return TodayAssignmentResponse.fromJson(decoded);
          }
        }
      }
      rethrow;
    }
  }

  Future<PunchInResponse> punchIn({
    required String token,
    required double lat,
    required double lng,
    double? accuracyM,
    String? exceptionReason,
    String? projectId,
    String? clientPunchId,
    String? clientPunchTimeIso,
    bool? isOffline,
  }) async {
    final uri = await api.url("/api/v1/engineer/punch-in");
    final body = <String, dynamic>{"lat": lat, "lng": lng};
    final pid = (projectId ?? "").trim();
    if (pid.isNotEmpty) body["project_id"] = pid;
    if (accuracyM != null) body["accuracy_m"] = accuracyM;
    final reason = (exceptionReason ?? "").trim();
    if (reason.isNotEmpty) body["exception_reason"] = reason;
    final cid = (clientPunchId ?? "").trim();
    if (cid.isNotEmpty) body["client_punch_id"] = cid;
    final ctime = (clientPunchTimeIso ?? "").trim();
    if (ctime.isNotEmpty) body["client_punch_time"] = ctime;
    if (isOffline != null) body["is_offline"] = isOffline;
    final json = await api.postJson(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode(body),
    );
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return PunchInResponse.fromJson(json);
  }

  Future<PunchOutResponse> punchOut({
    required String token,
    required double lat,
    required double lng,
    double? accuracyM,
    String? exceptionReason,
    required String remarks,
    String? clientPunchId,
    String? clientPunchTimeIso,
    bool? isOffline,
  }) async {
    final uri = await api.url("/api/v1/engineer/punch-out");
    final body = <String, dynamic>{"lat": lat, "lng": lng, "remarks": remarks};
    if (accuracyM != null) body["accuracy_m"] = accuracyM;
    final reason = (exceptionReason ?? "").trim();
    if (reason.isNotEmpty) body["exception_reason"] = reason;
    final cid = (clientPunchId ?? "").trim();
    if (cid.isNotEmpty) body["client_punch_id"] = cid;
    final ctime = (clientPunchTimeIso ?? "").trim();
    if (ctime.isNotEmpty) body["client_punch_time"] = ctime;
    if (isOffline != null) body["is_offline"] = isOffline;
    final json = await api.postJson(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode(body),
    );
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return PunchOutResponse.fromJson(json);
  }

  Future<EngineerHistoryResponse> history({required String token, String? month}) async {
    final qs = (month != null && month.trim().isNotEmpty) ? "?month=${Uri.encodeComponent(month.trim())}" : "";
    final uri = await api.url("/api/v1/engineer/history$qs");
    final json = await api.getJson(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerHistoryResponse.fromJson(json);
  }

  Future<EngineerTimesheetListResponse> timesheets({
    required String token,
    String? month,
    String? startDate,
    String? endDate,
    String? client,
    String? project,
    String? site,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (month != null && month.trim().isNotEmpty) params["month"] = month.trim();
    if (startDate != null && startDate.trim().isNotEmpty) params["start_date"] = startDate.trim();
    if (endDate != null && endDate.trim().isNotEmpty) params["end_date"] = endDate.trim();
    if (client != null && client.trim().isNotEmpty) params["client"] = client.trim();
    if (project != null && project.trim().isNotEmpty) params["project"] = project.trim();
    if (site != null && site.trim().isNotEmpty) params["site"] = site.trim();
    if (limit != null && limit > 0) params["limit"] = "$limit";
    final qs = params.isEmpty ? "" : "?${Uri(queryParameters: params).query}";

    final uri = await api.url("/api/v1/engineer/timesheets$qs");
    final json = await api.getJson(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerTimesheetListResponse.fromJson(json);
  }

  Future<EngineerTimesheetFilterOptionsResponse> timesheetFilterOptions({
    required String token,
    String? month,
    String? startDate,
    String? endDate,
    String? client,
    String? project,
  }) async {
    final params = <String, String>{};
    if (month != null && month.trim().isNotEmpty) params["month"] = month.trim();
    if (startDate != null && startDate.trim().isNotEmpty) params["start_date"] = startDate.trim();
    if (endDate != null && endDate.trim().isNotEmpty) params["end_date"] = endDate.trim();
    if (client != null && client.trim().isNotEmpty) params["client"] = client.trim();
    if (project != null && project.trim().isNotEmpty) params["project"] = project.trim();
    final qs = params.isEmpty ? "" : "?${Uri(queryParameters: params).query}";

    final uri = await api.url("/api/v1/engineer/timesheets/filters$qs");
    final json = await api.getJson(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerTimesheetFilterOptionsResponse.fromJson(json);
  }

  Future<EngineerTimesheetDetailResponse> timesheetDetail({required String token, required String workDate}) async {
    final uri = await api.url("/api/v1/engineer/timesheets/${Uri.encodeComponent(workDate.trim())}");
    final json = await api.getJson(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerTimesheetDetailResponse.fromJson(json);
  }

  Future<EngineerTimesheetDetailResponse> timesheetDetailByLog({required String token, required String attendanceLogId}) async {
    final uri = await api.url("/api/v1/engineer/timesheets/logs/${Uri.encodeComponent(attendanceLogId.trim())}");
    final json = await api.getJson(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerTimesheetDetailResponse.fromJson(json);
  }

  Future<({List<int> bytes, String filename})> timesheetsPdf({
    required String token,
    String? month,
    String? startDate,
    String? endDate,
    String? client,
    String? project,
    String? site,
  }) async {
    final params = <String, String>{};
    if (month != null && month.trim().isNotEmpty) params["month"] = month.trim();
    if (startDate != null && startDate.trim().isNotEmpty) params["start_date"] = startDate.trim();
    if (endDate != null && endDate.trim().isNotEmpty) params["end_date"] = endDate.trim();
    if (client != null && client.trim().isNotEmpty) params["client"] = client.trim();
    if (project != null && project.trim().isNotEmpty) params["project"] = project.trim();
    if (site != null && site.trim().isNotEmpty) params["site"] = site.trim();
    final qs = params.isEmpty ? "" : "?${Uri(queryParameters: params).query}";

    final uri = await api.url("/api/v1/engineer/timesheets.pdf$qs");
    final resp = await api.getBytes(uri, headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    final filename = _filenameFromDisposition(resp.headers["content-disposition"]) ?? "timesheet.pdf";
    return (bytes: resp.bytes, filename: filename);
  }
}

String? _filenameFromDisposition(String? v) {
  if (v == null) return null;
  final parts = v.split(";");
  for (final part in parts) {
    final p = part.trim();
    final lower = p.toLowerCase();
    if (lower.startsWith("filename*=")) {
      var value = p.substring("filename*=".length).trim();
      if (value.startsWith("\"") && value.endsWith("\"") && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }
      final lowerValue = value.toLowerCase();
      if (lowerValue.startsWith("utf-8''")) {
        value = value.substring("UTF-8''".length);
      }
      final decoded = Uri.decodeFull(value).trim();
      return decoded.isEmpty ? null : decoded;
    }
    if (lower.startsWith("filename=")) {
      var value = p.substring("filename=".length).trim();
      if (value.startsWith("\"") && value.endsWith("\"") && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }
      final decoded = value.trim();
      return decoded.isEmpty ? null : decoded;
    }
  }
  return null;
}
