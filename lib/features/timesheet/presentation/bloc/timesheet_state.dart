part of 'timesheet_bloc.dart';

enum TimesheetStatus {
  initial,
  loading,
  loaded,
  submitting,
  submitSuccess,
  error
}

class TimesheetState extends Equatable {
  final TimesheetStatus status;
  final String projectName;
  final String siteName;
  final String projectId;
  final String attendanceLogId;
  final String uploadedPhotoUrl;
  final String errorMessage;
  final bool isPunchedIn;

  const TimesheetState({
    this.status = TimesheetStatus.initial,
    this.projectName = "",
    this.siteName = "",
    this.projectId = "",
    this.attendanceLogId = "",
    this.uploadedPhotoUrl = "",
    this.errorMessage = "",
    this.isPunchedIn = false,
  });

  TimesheetState copyWith({
    TimesheetStatus? status,
    String? projectName,
    String? siteName,
    String? projectId,
    String? attendanceLogId,
    String? uploadedPhotoUrl,
    String? errorMessage,
    bool? isPunchedIn,
  }) {
    return TimesheetState(
      status: status ?? this.status,
      projectName: projectName ?? this.projectName,
      siteName: siteName ?? this.siteName,
      projectId: projectId ?? this.projectId,
      attendanceLogId: attendanceLogId ?? this.attendanceLogId,
      uploadedPhotoUrl: uploadedPhotoUrl ?? this.uploadedPhotoUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      isPunchedIn: isPunchedIn ?? this.isPunchedIn,
    );
  }

  @override
  List<Object?> get props =>
      [status, projectName, siteName, projectId, attendanceLogId, uploadedPhotoUrl, errorMessage, isPunchedIn];
}
