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
          if (e == 'OUT_OF_RADIUS_REASON_REQUIRED') {
            break;
          }
          if (e is DioException && e.response == null) {
            break;
          }
          break;
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }
}
