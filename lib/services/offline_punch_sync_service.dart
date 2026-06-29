import "../services/assignment_service.dart";
import "../services/api_client.dart";
import "../services/offline_punch_queue.dart";

class OfflinePunchSyncService {
  OfflinePunchSyncService({OfflinePunchQueue? queue, AssignmentService? assignmentService})
      : queue = queue ?? OfflinePunchQueue(),
        assignmentService = assignmentService ?? AssignmentService();

  final OfflinePunchQueue queue;
  final AssignmentService assignmentService;

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
            await assignmentService.punchIn(
              token: token,
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
            await assignmentService.punchOut(
              token: token,
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
        } on ApiException catch (e) {
          if (e.statusCode == null) {
            break;
          }
          if (e.code == "OUT_OF_RADIUS_REASON_REQUIRED") {
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

