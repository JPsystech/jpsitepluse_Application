import "dart:io";

import "package:dio/dio.dart";
import "package:sitepulse_engineer/core/services/offline_timesheet_queue.dart";
import "package:sitepulse_engineer/features/timesheet/data/services/site_photo_service.dart";

class OfflineTimesheetSyncService {
  OfflineTimesheetSyncService(
      {OfflineTimesheetQueue? queue, SitePhotoService? sitePhotoService})
      : queue = queue ?? OfflineTimesheetQueue(),
        sitePhotoService = sitePhotoService ?? SitePhotoService();

  final OfflineTimesheetQueue queue;
  final SitePhotoService sitePhotoService;

  static bool _isSyncing = false;

  Future<int> sync({required String token}) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;
    try {
      final items = await queue.list();
      for (final t in items) {
        try {
          final file = File(t.photoPath);
          if (await file.exists()) {
            await sitePhotoService.uploadProgressPhoto(
              token: token,
              file: file,
              lat: t.lat,
              lng: t.lng,
              addressText: t.addressText,
              projectName: t.projectName,
              siteName: t.siteName,
              projectId: t.projectId,
              attendanceLogId: t.attendanceLogId,
              empCode: t.empCode,
              capturedAt: DateTime.parse(t.capturedAtIso),
            );
          }
          // If file doesn't exist, we still remove it from the queue because we can't upload it without a file.
          await queue.remove(id: t.id);
          synced += 1;
        } catch (e) {
          if (e is DioException) {
            print("OFFLINE TIMESHEET SYNC ERROR: ${e.response?.statusCode} - ${e.response?.data}");
            
            final statusCode = e.response?.statusCode;
            // 4xx errors (except 401, 408, 429) are permanent data/validation rejections
            if (statusCode != null && statusCode >= 400 && statusCode < 500 && 
                statusCode != 401 && statusCode != 408 && statusCode != 429) {
              // This timesheet was permanently rejected by the server.
              // Remove it from the queue so it doesn't block other timesheets.
              print("Discarding permanently rejected offline timesheet: ${t.id}");
              await queue.remove(id: t.id);
              continue; // Continue processing the rest of the queue
            }
          }
          
          // For network errors (response == null) or 5xx server errors, 
          // stop sync and try later.
          print("Halting timesheet sync due to transient error: $e");
          break;
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }
}

