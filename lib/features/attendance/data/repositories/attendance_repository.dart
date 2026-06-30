import 'package:sitepulse_engineer/features/attendance/data/models/punch_response_model.dart';
import 'package:sitepulse_engineer/features/attendance/data/services/attendance_service.dart';

class AttendanceRepository {
  final AttendanceService _attendanceService;

  AttendanceRepository({AttendanceService? attendanceService}) : _attendanceService = attendanceService ?? AttendanceService();

  Future<PunchInResponseModel> punchIn({
    required double lat,
    required double lng,
    double? accuracyM,
    String? exceptionReason,
    String? projectId,
    String? clientPunchId,
    String? clientPunchTimeIso,
    bool? isOffline,
  }) async {
    return await _attendanceService.punchIn(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      exceptionReason: exceptionReason,
      projectId: projectId,
      clientPunchId: clientPunchId,
      clientPunchTimeIso: clientPunchTimeIso,
      isOffline: isOffline,
    );
  }

  Future<PunchOutResponseModel> punchOut({
    required double lat,
    required double lng,
    double? accuracyM,
    String? exceptionReason,
    required String remarks,
    String? clientPunchId,
    String? clientPunchTimeIso,
    bool? isOffline,
  }) async {
    return await _attendanceService.punchOut(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      exceptionReason: exceptionReason,
      remarks: remarks,
      clientPunchId: clientPunchId,
      clientPunchTimeIso: clientPunchTimeIso,
      isOffline: isOffline,
    );
  }
}
