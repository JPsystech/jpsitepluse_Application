import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

class OfflineSyncStore {
  static const String _punchQueueKey = "offline_punch_queue";
  static const String _documentQueueKey = "offline_document_queue";
  static const String _dashboardCacheKey = "offline_dashboard_cache";
  static const String _assignmentsCacheKey = "offline_assignments_cache";
  static const String _timesheetCacheKey = "offline_timesheet_cache";

  // --- Read-Only Caching ---

  static Future<void> cacheDashboard(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dashboardCacheKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getCachedDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_dashboardCacheKey);
    if (str != null) return jsonDecode(str);
    return null;
  }

  static Future<void> cacheAssignments(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assignmentsCacheKey, jsonEncode(data));
  }

  static Future<List<dynamic>?> getCachedAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_assignmentsCacheKey);
    if (str != null) return jsonDecode(str);
    return null;
  }

  static Future<void> cacheTimesheet(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timesheetCacheKey, jsonEncode(data));
  }

  static Future<List<dynamic>?> getCachedTimesheet() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_timesheetCacheKey);
    if (str != null) return jsonDecode(str);
    return null;
  }

  // --- Write-Action Queue (Punches) ---

  static Future<void> queuePunchAction(Map<String, dynamic> actionData) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_punchQueueKey);
    List<dynamic> queue = [];
    if (str != null) {
      queue = jsonDecode(str);
    }
    // ensure offline flag
    actionData["is_offline"] = true;
    if (!actionData.containsKey("client_punch_time")) {
      actionData["client_punch_time"] = DateTime.now().toUtc().toIso8601String();
    }
    queue.add(actionData);
    await prefs.setString(_punchQueueKey, jsonEncode(queue));
  }

  static Future<List<dynamic>> getPunchQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_punchQueueKey);
    if (str != null) {
      return jsonDecode(str);
    }
    return [];
  }

  static Future<void> clearPunchQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_punchQueueKey);
  }

  // --- Write-Action Queue (Documents) ---

  static Future<void> queueDocumentUpload(Map<String, dynamic> uploadData) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_documentQueueKey);
    List<dynamic> queue = [];
    if (str != null) {
      queue = jsonDecode(str);
    }
    // ensure offline flag and timestamp
    uploadData["is_offline"] = true;
    if (!uploadData.containsKey("queued_at")) {
      uploadData["queued_at"] = DateTime.now().toUtc().toIso8601String();
    }
    queue.add(uploadData);
    await prefs.setString(_documentQueueKey, jsonEncode(queue));
  }

  static Future<List<dynamic>> getDocumentQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_documentQueueKey);
    if (str != null) {
      return jsonDecode(str);
    }
    return [];
  }

  static Future<void> removeDocumentFromQueue(String localFilePath) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_documentQueueKey);
    if (str != null) {
      List<dynamic> queue = jsonDecode(str);
      queue.removeWhere((item) => item['local_file_path'] == localFilePath);
      await prefs.setString(_documentQueueKey, jsonEncode(queue));
    }
  }

  static Future<void> clearDocumentQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_documentQueueKey);
  }
}

