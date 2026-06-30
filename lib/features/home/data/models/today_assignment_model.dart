class TodayAssignmentModel {
  final String projectId;
  final String projectName;
  final String siteName;
  final String? clientName;
  final String? address;
  final double latitude;
  final double longitude;
  final int allowedRadiusM;
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
      todayStatus: json["today_status"] as String?,
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

  TodayAssignmentResponseModel({
    required this.hasAssignment,
    required this.assignment,
    required this.assignments,
    required this.message,
    required this.activeAttendanceLogId,
    required this.activeProjectId,
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
    );
  }
}
