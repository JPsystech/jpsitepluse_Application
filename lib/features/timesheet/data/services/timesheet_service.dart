import "dart:convert";
import "dart:io";
import "package:shared_preferences/shared_preferences.dart";
import "package:sitepulse_engineer/core/services/api_client.dart";
import "package:sitepulse_engineer/shared/models/today_assignment.dart";

class TimesheetService {
  final ApiClient api;

  TimesheetService({ApiClient? api}) : api = api ?? ApiClient();

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
    if (month != null && month.trim().isNotEmpty) {
      params["month"] = month.trim();
    }
    if (startDate != null && startDate.trim().isNotEmpty) {
      params["start_date"] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params["end_date"] = endDate.trim();
    }
    if (client != null && client.trim().isNotEmpty) {
      params["client"] = client.trim();
    }
    if (project != null && project.trim().isNotEmpty) {
      params["project"] = project.trim();
    }
    if (site != null && site.trim().isNotEmpty) params["site"] = site.trim();
    if (limit != null && limit > 0) params["limit"] = "$limit";
    final qs = params.isEmpty ? "" : "?${Uri(queryParameters: params).query}";

    final uri = await api.url("/api/v1/engineer/timesheets$qs");
    // Cache key based on month (or default if no month provided)
    final cacheKey = "cached_timesheets_v1_${month?.trim() ?? 'default'}";

    try {
      final json = await api.getJson(uri,
          headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
      if (json == null) {
        throw ApiException("Invalid response from server");
      }
      
      // Save to cache on success
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(json));

      return EngineerTimesheetListResponse.fromJson(json);
    } catch (e) {
      final err = e.toString().toLowerCase();
      final isOffline = err.contains('connection failed') || 
                        err.contains('socketexception') || 
                        err.contains('failed host lookup') || 
                        err.contains('network is unreachable');
      
      if (isOffline) {
        // Try to load from cache
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          final Map<String, dynamic> json = jsonDecode(cachedData);
          return EngineerTimesheetListResponse.fromJson(json);
        } else {
          throw Exception("You are offline and no data is available for this month.");
        }
      }
      rethrow;
    }
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
    if (month != null && month.trim().isNotEmpty) {
      params["month"] = month.trim();
    }
    if (startDate != null && startDate.trim().isNotEmpty) {
      params["start_date"] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params["end_date"] = endDate.trim();
    }
    if (client != null && client.trim().isNotEmpty) {
      params["client"] = client.trim();
    }
    if (project != null && project.trim().isNotEmpty) {
      params["project"] = project.trim();
    }
    final qs = params.isEmpty ? "" : "?${Uri(queryParameters: params).query}";

    final uri = await api.url("/api/v1/engineer/timesheets/filters$qs");
    // Cache key based on month (or default if no month provided)
    final cacheKey = "cached_timesheet_filters_v1_${month?.trim() ?? 'default'}";

    try {
      final json = await api.getJson(uri,
          headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
      if (json == null) {
        throw ApiException("Invalid response from server");
      }
      
      // Save to cache on success
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(json));

      return EngineerTimesheetFilterOptionsResponse.fromJson(json);
    } catch (e) {
      final err = e.toString().toLowerCase();
      final isOffline = err.contains('connection failed') || 
                        err.contains('socketexception') || 
                        err.contains('failed host lookup') || 
                        err.contains('network is unreachable');
      
      if (isOffline) {
        // Try to load from cache
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          final Map<String, dynamic> json = jsonDecode(cachedData);
          return EngineerTimesheetFilterOptionsResponse.fromJson(json);
        } else {
          throw Exception("You are offline and no cached filters are available.");
        }
      }
      rethrow;
    }
  }

  Future<EngineerTimesheetDetailResponse> timesheetDetail(
      {required String token, required String workDate}) async {
    final uri = await api.url(
        "/api/v1/engineer/timesheets/${Uri.encodeComponent(workDate.trim())}");
    final json = await api.getJson(uri,
        headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerTimesheetDetailResponse.fromJson(json);
  }

  Future<EngineerTimesheetDetailResponse> timesheetDetailByLog(
      {required String token, required String attendanceLogId}) async {
    final uri = await api.url(
        "/api/v1/engineer/timesheets/logs/${Uri.encodeComponent(attendanceLogId.trim())}");
    final json = await api.getJson(uri,
        headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
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
    if (month != null && month.trim().isNotEmpty) {
      params["month"] = month.trim();
    }
    if (startDate != null && startDate.trim().isNotEmpty) {
      params["start_date"] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params["end_date"] = endDate.trim();
    }
    if (client != null && client.trim().isNotEmpty) {
      params["client"] = client.trim();
    }
    if (project != null && project.trim().isNotEmpty) {
      params["project"] = project.trim();
    }
    if (site != null && site.trim().isNotEmpty) params["site"] = site.trim();
    final qs = params.isEmpty ? "" : "?${Uri(queryParameters: params).query}";

    final uri = await api.url("/api/v1/engineer/timesheets.pdf$qs");
    final resp = await api.getBytes(uri,
        headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    final filename =
        _filenameFromDisposition(resp.headers["content-disposition"]) ??
            "timesheet.pdf";
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
