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
          // If it's a network error (no response), break and try again later
          if (e is DioException && e.response == null) {
            break;
          }
          // If it's a 4xx error or other error, we might want to drop it, but we'll break to be safe.
          break;
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }
}

