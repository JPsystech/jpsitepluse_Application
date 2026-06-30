part of 'timesheet_bloc.dart';

enum TimesheetStatus { initial, loading, loaded, submitting, submitSuccess, error }

class TimesheetState extends Equatable {
  final TimesheetStatus status;
  final String projectName;
  final String siteName;
  final String uploadedPhotoUrl;
  final String errorMessage;

  const TimesheetState({
    this.status = TimesheetStatus.initial,
    this.projectName = "",
    this.siteName = "",
    this.uploadedPhotoUrl = "",
    this.errorMessage = "",
  });

  TimesheetState copyWith({
    TimesheetStatus? status,
    String? projectName,
    String? siteName,
    String? uploadedPhotoUrl,
    String? errorMessage,
  }) {
    return TimesheetState(
      status: status ?? this.status,
      projectName: projectName ?? this.projectName,
      siteName: siteName ?? this.siteName,
      uploadedPhotoUrl: uploadedPhotoUrl ?? this.uploadedPhotoUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, projectName, siteName, uploadedPhotoUrl, errorMessage];
}
