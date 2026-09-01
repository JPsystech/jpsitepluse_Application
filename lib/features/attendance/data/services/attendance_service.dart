import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/features/attendance/data/models/punch_response_model.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/offline_sync_store.dart';

class AttendanceService {
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
    final client = await ApiClient.instance.dio;
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

    try {
      final response =
          await client.post('/api/v1/engineer/punch-in', data: body);
      return PunchInResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['code'] == 'OUT_OF_RADIUS_REASON_REQUIRED') {
        throw 'OUT_OF_RADIUS_REASON_REQUIRED';
      }
      rethrow;
    }
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
    final client = await ApiClient.instance.dio;
    final body = <String, dynamic>{"lat": lat, "lng": lng, "remarks": remarks};
    if (accuracyM != null) body["accuracy_m"] = accuracyM;
    final reason = (exceptionReason ?? "").trim();
    if (reason.isNotEmpty) body["exception_reason"] = reason;
    final cid = (clientPunchId ?? "").trim();
    if (cid.isNotEmpty) body["client_punch_id"] = cid;
    final ctime = (clientPunchTimeIso ?? "").trim();
    if (ctime.isNotEmpty) body["client_punch_time"] = ctime;
    if (isOffline != null) body["is_offline"] = isOffline;

    try {
      final response =
          await client.post('/api/v1/engineer/punch-out', data: body);
      return PunchOutResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['code'] == 'OUT_OF_RADIUS_REASON_REQUIRED') {
        throw 'OUT_OF_RADIUS_REASON_REQUIRED';
      }
      rethrow;
    }
  }
}
