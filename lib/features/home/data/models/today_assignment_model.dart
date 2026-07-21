class TodayAssignmentModel {
  final String projectId;
  final String projectName;
  final String siteName;
  final String? clientName;
  final String? address;
  final double latitude;
  final double longitude;
  final int allowedRadiusM;
  final String? todayActiveHours;
  final String? todayPunchInTime;
  final String? todayPunchOutTime;
  final String? todayStatus;

  TodayAssignmentModel({
    required this.projectId,
    required this.projectName,
    required this.siteName,
    required this.clientName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusM,
    this.todayActiveHours,
    this.todayPunchInTime,
    this.todayPunchOutTime,
    required this.todayStatus,
  });

  factory TodayAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TodayAssignmentModel(
      projectId: (json["project_id"] as String?) ?? "",
      projectName: (json["project_name"] as String?) ?? "",
      siteName: (json["site_name"] as String?) ?? "",
      clientName: json["client_name"] as String?,
      address: json["address"] as String?,
      latitude: (json["latitude"] as num?)?.toDouble() ?? 0,
      longitude: (json["longitude"] as num?)?.toDouble() ?? 0,
      allowedRadiusM: (json["allowed_radius_m"] as num?)?.toInt() ?? 0,
      todayActiveHours: json["today_active_hours"] as String?,
      todayPunchInTime: json["today_punch_in_time"] as String?,
      todayPunchOutTime: json["today_punch_out_time"] as String?,
      todayStatus: json["today_status"] as String?,
    );
  }
}

class AttendanceOverviewModel {
  final String currentStatus;
  final String? firstPunchIn;
  final String activeHours;

  AttendanceOverviewModel({
    required this.currentStatus,
    this.firstPunchIn,
    required this.activeHours,
  });

  factory AttendanceOverviewModel.fromJson(Map<String, dynamic> json) {
    return AttendanceOverviewModel(
      currentStatus: json['current_status'] as String? ?? "OFF SITE",
      firstPunchIn: json['first_punch_in'] as String?,
      activeHours: json['active_hours'] as String? ?? "0m",
    );
  }
}

class WeeklySummaryModel {
  final String totalHours;
  final int daysActive;

  WeeklySummaryModel({
    required this.totalHours,
    required this.daysActive,
  });

  factory WeeklySummaryModel.fromJson(Map<String, dynamic> json) {
    return WeeklySummaryModel(
      totalHours: json['total_hours'] as String? ?? "0m",
      daysActive: json['days_active'] as int? ?? 0,
    );
  }
}

class TodayAssignmentResponseModel {
  final bool hasAssignment;
  final TodayAssignmentModel? assignment;
  final List<TodayAssignmentModel> assignments;
  final String? message;
  final String? activeAttendanceLogId;
  final String? activeProjectId;
  final AttendanceOverviewModel? attendanceOverview;
  final WeeklySummaryModel? weeklySummary;

  TodayAssignmentResponseModel({
    required this.hasAssignment,
    required this.assignment,
    required this.assignments,
    required this.message,
    required this.activeAttendanceLogId,
    required this.activeProjectId,
    this.attendanceOverview,
    this.weeklySummary,
  });

  factory TodayAssignmentResponseModel.fromJson(Map<String, dynamic> json) {
    final a = json["assignment"];
    final rawList = json["assignments"];
    final list = rawList is List
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(TodayAssignmentModel.fromJson)
            .toList()
        : <TodayAssignmentModel>[];
    final single =
        a is Map<String, dynamic> ? TodayAssignmentModel.fromJson(a) : null;
    return TodayAssignmentResponseModel(
      hasAssignment: (json["has_assignment"] as bool?) ?? false,
      assignment: single,
      assignments: list.isNotEmpty
          ? list
          : (single != null ? [single] : <TodayAssignmentModel>[]),
      message: json["message"] as String?,
      activeAttendanceLogId: json["active_attendance_log_id"] as String?,
      activeProjectId: json["active_project_id"] as String?,
      attendanceOverview: json["attendance_overview"] != null
          ? AttendanceOverviewModel.fromJson(json["attendance_overview"])
          : null,
      weeklySummary: json["weekly_summary"] != null
          ? WeeklySummaryModel.fromJson(json["weekly_summary"])
          : null,
    );
  }
}
