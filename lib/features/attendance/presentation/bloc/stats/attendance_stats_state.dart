part of 'attendance_stats_bloc.dart';

enum AttendanceStatsStatus { initial, loading, success, error }

class AttendanceStatsState extends Equatable {
  final AttendanceStatsStatus status;
  final EngineerTimesheetListResponse? data;
  final String? errorMessage;

  const AttendanceStatsState({
    this.status = AttendanceStatsStatus.initial,
    this.data,
    this.errorMessage,
  });

  AttendanceStatsState copyWith({
    AttendanceStatsStatus? status,
    EngineerTimesheetListResponse? data,
    String? errorMessage,
  }) {
    return AttendanceStatsState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, data, errorMessage];
}
