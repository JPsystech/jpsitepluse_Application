import "package:sitepulse_engineer/features/attendance/data/services/attendance_service.dart";
import "package:dio/dio.dart";
import "package:sitepulse_engineer/core/services/offline_punch_queue.dart";

class OfflinePunchSyncService {
  OfflinePunchSyncService(
      {OfflinePunchQueue? queue, AttendanceService? attendanceService})
      : queue = queue ?? OfflinePunchQueue(),
        attendanceService = attendanceService ?? AttendanceService();

  final OfflinePunchQueue queue;
  final AttendanceService attendanceService;

  static bool _isSyncing = false;

  Future<int> sync({required String token}) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;
    try {
      final items = await queue.list();
      for (final p in items) {
        try {
          if (p.type == OfflinePunchType.inPunch) {
            await attendanceService.punchIn(
              lat: p.lat,
              lng: p.lng,
              accuracyM: p.accuracyM,
              exceptionReason: p.exceptionReason,
              projectId: p.projectId,
              clientPunchId: p.clientPunchId,
              clientPunchTimeIso: p.clientPunchTimeIso,
              isOffline: true,
            );
          } else {
            await attendanceService.punchOut(
              lat: p.lat,
              lng: p.lng,
              accuracyM: p.accuracyM,
              exceptionReason: p.exceptionReason,
              remarks: p.remarks ?? "",
              clientPunchId: p.clientPunchId,
              clientPunchTimeIso: p.clientPunchTimeIso,
              isOffline: true,
            );
          }
          await queue.remove(clientPunchId: p.clientPunchId, type: p.type);
          synced += 1;
        } catch (e) {
          if (e is DioException) {
            print("OFFLINE PUNCH SYNC ERROR: ${e.response?.statusCode} - ${e.response?.data}");
            
            final statusCode = e.response?.statusCode;
            // 4xx errors (except 401, 408, 429) are permanent data/validation rejections
            if (statusCode != null && statusCode >= 400 && statusCode < 500 && 
                statusCode != 401 && statusCode != 408 && statusCode != 429) {
              // This punch was permanently rejected by the server (e.g. too old, conflicts).
              // Remove it from the queue so it doesn't block other punches.
              print("Discarding permanently rejected offline punch: ${p.clientPunchId}");
              await queue.remove(clientPunchId: p.clientPunchId, type: p.type);
              continue; // Continue processing the rest of the queue
            }
          }
          
          // For network errors (response == null) or 5xx server errors, 
          // stop sync and try later.
          print("Halting punch sync due to transient error: $e");
          break;
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }
}
