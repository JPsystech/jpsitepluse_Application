class TodayAssignmentResponse {
  final bool hasAssignment;
  final TodayAssignment? assignment;
  final List<TodayAssignment> assignments;
  final String? message;
  final String? activeAttendanceLogId;
  final String? activeProjectId;
  final bool isProfileComplete;

  TodayAssignmentResponse({
    required this.hasAssignment,
    required this.assignment,
    required this.assignments,
    required this.message,
    required this.activeAttendanceLogId,
    required this.activeProjectId,
    this.isProfileComplete = true,
  });

  factory TodayAssignmentResponse.fromJson(Map<String, dynamic> json) {
    final a = json["assignment"];
    final rawList = json["assignments"];
    final list = rawList is List
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(TodayAssignment.fromJson)
            .toList()
        : <TodayAssignment>[];
    final single =
        a is Map<String, dynamic> ? TodayAssignment.fromJson(a) : null;
    return TodayAssignmentResponse(
      hasAssignment: (json["has_assignment"] as bool?) ?? false,
      assignment: single,
      assignments: list.isNotEmpty
          ? list
          : (single != null ? [single] : <TodayAssignment>[]),
      message: json["message"] as String?,
      activeAttendanceLogId: json["active_attendance_log_id"] as String?,
      activeProjectId: json["active_project_id"] as String?,
      isProfileComplete: (json["is_profile_complete"] as bool?) ?? true,
    );
  }
}

class TodayAssignment {
  final String projectId;
  final String projectName;
  final String siteName;
  final String? clientName;
  final String? address;
  final double latitude;
  final double longitude;
  final int allowedRadiusM;
  final String? todayStatus;

  TodayAssignment({
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

  factory TodayAssignment.fromJson(Map<String, dynamic> json) {
    return TodayAssignment(
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

class PunchInResponse {
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

  PunchInResponse({
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

  factory PunchInResponse.fromJson(Map<String, dynamic> json) {
    return PunchInResponse(
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

class PunchOutResponse {
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

  PunchOutResponse({
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

  factory PunchOutResponse.fromJson(Map<String, dynamic> json) {
    return PunchOutResponse(
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

class EngineerHistoryResponse {
  final String startDate;
  final String endDate;
  final List<EngineerHistoryRow> items;

  EngineerHistoryResponse(
      {required this.startDate, required this.endDate, required this.items});

  factory EngineerHistoryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json["items"];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(EngineerHistoryRow.fromJson)
            .toList()
        : <EngineerHistoryRow>[];
    return EngineerHistoryResponse(
      startDate: (json["start_date"] as String?) ?? "",
      endDate: (json["end_date"] as String?) ?? "",
      items: items,
    );
  }
}

class EngineerHistoryRow {
  final String workDate;
  final String projectName;
  final String siteName;
  final DateTime punchInTime;
  final DateTime? punchOutTime;
  final String? remarks;
  final String status;
  final List<String> punchInPhotoUrls;
  final List<String> punchOutPhotoUrls;
  final List<String> progressPhotoUrls;

  EngineerHistoryRow({
    required this.workDate,
    required this.projectName,
    required this.siteName,
    required this.punchInTime,
    required this.punchOutTime,
    required this.remarks,
    required this.status,
    required this.punchInPhotoUrls,
    required this.punchOutPhotoUrls,
    required this.progressPhotoUrls,
  });

  factory EngineerHistoryRow.fromJson(Map<String, dynamic> json) {
    List<String> readUrls(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    final punchInTime =
        DateTime.tryParse((json["punch_in_time"] as String?) ?? "") ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final punchOutTimeRaw = (json["punch_out_time"] as String?);

    return EngineerHistoryRow(
      workDate: (json["work_date"] as String?) ?? "",
      projectName: (json["project_name"] as String?) ?? "",
      siteName: (json["site_name"] as String?) ?? "",
      punchInTime: punchInTime,
      punchOutTime:
          punchOutTimeRaw != null ? DateTime.tryParse(punchOutTimeRaw) : null,
      remarks: (json["remarks"] as String?),
      status: (json["status"] as String?) ?? "",
      punchInPhotoUrls: readUrls("punch_in_photo_urls"),
      punchOutPhotoUrls: readUrls("punch_out_photo_urls"),
      progressPhotoUrls: readUrls("progress_photo_urls"),
    );
  }
}

class EngineerTimesheetListResponse {
  final String startDate;
  final String endDate;
  final List<EngineerTimesheetRow> items;
  final int totalPresentDays;
  final double totalHours;
  final List<int> weeklyOffDays;

  EngineerTimesheetListResponse({
    required this.startDate,
    required this.endDate,
    required this.items,
    required this.totalPresentDays,
    required this.totalHours,
    this.weeklyOffDays = const [6],
  });

  factory EngineerTimesheetListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json["items"];
    final items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(EngineerTimesheetRow.fromJson)
            .toList()
        : <EngineerTimesheetRow>[];

    List<int> parsedWeeklyOff = const [6];
    final rawWeeklyOff = json["weekly_off_days"];
    if (rawWeeklyOff is List) {
      parsedWeeklyOff = rawWeeklyOff
          .map((e) => (e as num?)?.toInt())
          .whereType<int>()
          .toList();
      if (parsedWeeklyOff.isEmpty) parsedWeeklyOff = const [6];
    } else if (rawWeeklyOff is String && rawWeeklyOff.trim().isNotEmpty) {
      parsedWeeklyOff = rawWeeklyOff
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      if (parsedWeeklyOff.isEmpty) parsedWeeklyOff = const [6];
    }

    return EngineerTimesheetListResponse(
      startDate: (json["start_date"] as String?) ?? "",
      endDate: (json["end_date"] as String?) ?? "",
      items: items,
      totalPresentDays: (json["total_present_days"] as num?)?.toInt() ?? 0,
      totalHours: (json["total_hours"] as num?)?.toDouble() ?? 0,
      weeklyOffDays: parsedWeeklyOff,
    );
  }
}

class EngineerTimesheetRow {
  final String attendanceLogId;
  final String workDate;
  final String? clientName;
  final String projectId;
  final String projectName;
  final String siteName;
  final DateTime punchInTime;
  final DateTime? punchOutTime;
  final double totalHours;
  final String? remarks;
  final String? mark;
  final String? status;
  final bool? isOutOfRadius;

  EngineerTimesheetRow({
    required this.attendanceLogId,
    required this.workDate,
    required this.clientName,
    required this.projectId,
    required this.projectName,
    required this.siteName,
    required this.punchInTime,
    required this.punchOutTime,
    required this.totalHours,
    required this.remarks,
    required this.mark,
    this.status,
    this.isOutOfRadius,
  });

  factory EngineerTimesheetRow.fromJson(Map<String, dynamic> json) {
    final punchInTime =
        DateTime.tryParse((json["punch_in_time"] as String?) ?? "") ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final punchOutTimeRaw = json["punch_out_time"] as String?;
    return EngineerTimesheetRow(
      attendanceLogId: (json["attendance_log_id"] as String?) ?? "",
      workDate: (json["work_date"] as String?) ?? "",
      clientName: json["client_name"] as String?,
      projectId: (json["project_id"] as String?) ?? "",
      projectName: (json["project_name"] as String?) ?? "",
      siteName: (json["site_name"] as String?) ?? "",
      punchInTime: punchInTime,
      punchOutTime:
          punchOutTimeRaw != null ? DateTime.tryParse(punchOutTimeRaw) : null,
      totalHours: (json["total_hours"] as num?)?.toDouble() ?? 0,
      remarks: json["remarks"] as String?,
      mark: json["mark"] as String?,
      status: json["status"] as String?,
      isOutOfRadius: (json["is_out_of_radius"] as bool?) ??
          (json["punch_in_is_inside_radius"] == false ||
              json["punch_out_is_inside_radius"] == false ||
              json["punch_in_is_exception_punch"] == true ||
              json["punch_out_is_exception_punch"] == true),
    );
  }
}

class EngineerTimesheetFilterOptionsResponse {
  final List<String> clients;
  final List<String> projects;
  final List<String> sites;

  EngineerTimesheetFilterOptionsResponse(
      {required this.clients, required this.projects, required this.sites});

  factory EngineerTimesheetFilterOptionsResponse.fromJson(
      Map<String, dynamic> json) {
    List<String> readList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    return EngineerTimesheetFilterOptionsResponse(
      clients: readList("clients"),
      projects: readList("projects"),
      sites: readList("sites"),
    );
  }
}

class EngineerTimesheetDetailResponse {
  final String workDate;
  final String? clientName;
  final String projectId;
  final String projectName;
  final String siteName;
  final String? address;
  final String status;
  final DateTime punchInTime;
  final double punchInLat;
  final double punchInLng;
  final double punchInDistanceM;
  final DateTime? punchOutTime;
  final double? punchOutLat;
  final double? punchOutLng;
  final double? punchOutDistanceM;
  final String? punchOutRemarks;
  final double totalHours;
  final String? mark;
  final List<String> punchInPhotoUrls;
  final List<String> punchOutPhotoUrls;
  final List<String> progressPhotoUrls;

  EngineerTimesheetDetailResponse({
    required this.workDate,
    required this.clientName,
    required this.projectId,
    required this.projectName,
    required this.siteName,
    required this.address,
    required this.status,
    required this.punchInTime,
    required this.punchInLat,
    required this.punchInLng,
    required this.punchInDistanceM,
    required this.punchOutTime,
    required this.punchOutLat,
    required this.punchOutLng,
    required this.punchOutDistanceM,
    required this.punchOutRemarks,
    required this.totalHours,
    required this.mark,
    required this.punchInPhotoUrls,
    required this.punchOutPhotoUrls,
    required this.progressPhotoUrls,
  });

  factory EngineerTimesheetDetailResponse.fromJson(Map<String, dynamic> json) {
    List<String> readUrls(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    final punchInTime =
        DateTime.tryParse((json["punch_in_time"] as String?) ?? "") ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final punchOutTimeRaw = json["punch_out_time"] as String?;

    return EngineerTimesheetDetailResponse(
      workDate: (json["work_date"] as String?) ?? "",
      clientName: json["client_name"] as String?,
      projectId: (json["project_id"] as String?) ?? "",
      projectName: (json["project_name"] as String?) ?? "",
      siteName: (json["site_name"] as String?) ?? "",
      address: json["address"] as String?,
      status: (json["status"] as String?) ?? "",
      punchInTime: punchInTime,
      punchInLat: (json["punch_in_lat"] as num?)?.toDouble() ?? 0,
      punchInLng: (json["punch_in_lng"] as num?)?.toDouble() ?? 0,
      punchInDistanceM: (json["punch_in_distance_m"] as num?)?.toDouble() ?? 0,
      punchOutTime:
          punchOutTimeRaw != null ? DateTime.tryParse(punchOutTimeRaw) : null,
      punchOutLat: (json["punch_out_lat"] as num?)?.toDouble(),
      punchOutLng: (json["punch_out_lng"] as num?)?.toDouble(),
      punchOutDistanceM: (json["punch_out_distance_m"] as num?)?.toDouble(),
      punchOutRemarks: json["punch_out_remarks"] as String?,
      totalHours: (json["total_hours"] as num?)?.toDouble() ?? 0,
      mark: json["mark"] as String?,
      punchInPhotoUrls: readUrls("punch_in_photo_urls"),
      punchOutPhotoUrls: readUrls("punch_out_photo_urls"),
      progressPhotoUrls: readUrls("progress_photo_urls"),
    );
  }
}
