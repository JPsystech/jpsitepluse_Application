class PunchInResponseModel {
  final String attendanceLogId;
  final String workDate;
  final DateTime punchInTime;
  final double punchInLat;
  final double punchInLng;
  final double punchInDistanceM;
  final bool? isInsideRadius;
  final bool? isExceptionPunch;
  final String? exceptionStatus;
  final String status;

  PunchInResponseModel({
    required this.attendanceLogId,
    required this.workDate,
    required this.punchInTime,
    required this.punchInLat,
    required this.punchInLng,
    required this.punchInDistanceM,
    required this.isInsideRadius,
    required this.isExceptionPunch,
    required this.exceptionStatus,
    required this.status,
  });

  factory PunchInResponseModel.fromJson(Map<String, dynamic> json) {
    return PunchInResponseModel(
      attendanceLogId: (json["attendance_log_id"] as String?) ?? "",
      workDate: (json["work_date"] as String?) ?? "",
      punchInTime:
          DateTime.tryParse((json["punch_in_time"] as String?) ?? "") ??
              DateTime.fromMillisecondsSinceEpoch(0),
      punchInLat: (json["punch_in_lat"] as num?)?.toDouble() ?? 0,
      punchInLng: (json["punch_in_lng"] as num?)?.toDouble() ?? 0,
      punchInDistanceM: (json["punch_in_distance_m"] as num?)?.toDouble() ?? 0,
      isInsideRadius: json["is_inside_radius"] as bool?,
      isExceptionPunch: json["is_exception_punch"] as bool?,
      exceptionStatus: json["exception_status"] as String?,
      status: (json["status"] as String?) ?? "",
    );
  }
}

class PunchOutResponseModel {
  final String attendanceLogId;
  final String workDate;
  final DateTime punchOutTime;
  final double punchOutLat;
  final double punchOutLng;
  final double punchOutDistanceM;
  final bool? isInsideRadius;
  final bool? isExceptionPunch;
  final String? exceptionStatus;
  final String punchOutRemarks;
  final String status;

  PunchOutResponseModel({
    required this.attendanceLogId,
    required this.workDate,
    required this.punchOutTime,
    required this.punchOutLat,
    required this.punchOutLng,
    required this.punchOutDistanceM,
    required this.isInsideRadius,
    required this.isExceptionPunch,
    required this.exceptionStatus,
    required this.punchOutRemarks,
    required this.status,
  });

  factory PunchOutResponseModel.fromJson(Map<String, dynamic> json) {
    return PunchOutResponseModel(
      attendanceLogId: (json["attendance_log_id"] as String?) ?? "",
      workDate: (json["work_date"] as String?) ?? "",
      punchOutTime:
          DateTime.tryParse((json["punch_out_time"] as String?) ?? "") ??
              DateTime.fromMillisecondsSinceEpoch(0),
      punchOutLat: (json["punch_out_lat"] as num?)?.toDouble() ?? 0,
      punchOutLng: (json["punch_out_lng"] as num?)?.toDouble() ?? 0,
      punchOutDistanceM:
          (json["punch_out_distance_m"] as num?)?.toDouble() ?? 0,
      isInsideRadius: json["is_inside_radius"] as bool?,
      isExceptionPunch: json["is_exception_punch"] as bool?,
      exceptionStatus: json["exception_status"] as String?,
      punchOutRemarks: (json["punch_out_remarks"] as String?) ?? "",
      status: (json["status"] as String?) ?? "",
    );
  }
}
