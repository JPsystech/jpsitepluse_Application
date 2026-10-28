import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";
import "encrypted_file_store.dart";

class OfflineSyncStore {
  static const String _punchQueueKey = "offline_punch_queue";
  static const String _documentQueueKey = "offline_document_queue";
  static const String _dashboardCacheKey = "offline_dashboard_cache";
  static const String _assignmentsCacheKey = "offline_assignments_cache";
  static const String _timesheetCacheKey = "offline_timesheet_cache";

  static Future<String?> _read(String key) async {
    final encrypted = await EncryptedFileStore.read(key);
    if (encrypted != null) return encrypted;

    // One-time migration from previous unencrypted preferences. Do not delete
    // the legacy value until encrypted storage has been written successfully.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null) {
      await EncryptedFileStore.write(key, legacy);
      await prefs.remove(key);
    }
    return legacy;
  }

  static Future<void> _write(String key, String value) async {
    await EncryptedFileStore.write(key, value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> _clear(String key) async {
    await EncryptedFileStore.delete(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // --- Read-Only Caching ---

  static Future<void> cacheDashboard(Map<String, dynamic> data) async {
    await _write(_dashboardCacheKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getCachedDashboard() async {
    final str = await _read(_dashboardCacheKey);
    if (str != null) return jsonDecode(str);
    return null;
  }

  static Future<void> cacheAssignments(List<dynamic> data) async {
    await _write(_assignmentsCacheKey, jsonEncode(data));
  }

  static Future<List<dynamic>?> getCachedAssignments() async {
    final str = await _read(_assignmentsCacheKey);
    if (str != null) return jsonDecode(str);
    return null;
  }

  static Future<void> cacheTimesheet(List<dynamic> data) async {
    await _write(_timesheetCacheKey, jsonEncode(data));
  }

  static Future<List<dynamic>?> getCachedTimesheet() async {
    final str = await _read(_timesheetCacheKey);
    if (str != null) return jsonDecode(str);
    return null;
  }

  // --- Write-Action Queue (Punches) ---

  static Future<void> queuePunchAction(Map<String, dynamic> actionData) async {
    final str = await _read(_punchQueueKey);
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
    await _write(_punchQueueKey, jsonEncode(queue));
  }

  static Future<List<dynamic>> getPunchQueue() async {
    final str = await _read(_punchQueueKey);
    if (str != null) {
      return jsonDecode(str);
    }
    return [];
  }

  static Future<void> clearPunchQueue() async {
    await _clear(_punchQueueKey);
  }

  // --- Write-Action Queue (Documents) ---

  static Future<void> queueDocumentUpload(Map<String, dynamic> uploadData) async {
    final str = await _read(_documentQueueKey);
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
    await _write(_documentQueueKey, jsonEncode(queue));
  }

  static Future<List<dynamic>> getDocumentQueue() async {
    final str = await _read(_documentQueueKey);
    if (str != null) {
      return jsonDecode(str);
    }
    return [];
  }

  static Future<void> removeDocumentFromQueue(String localFilePath) async {
    final str = await _read(_documentQueueKey);
    if (str != null) {
      List<dynamic> queue = jsonDecode(str);
      queue.removeWhere((item) => item['local_file_path'] == localFilePath);
      await _write(_documentQueueKey, jsonEncode(queue));
    }
  }

  static Future<void> clearDocumentQueue() async {
    await _clear(_documentQueueKey);
  }
}

