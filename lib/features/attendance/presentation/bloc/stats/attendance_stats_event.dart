part of 'attendance_stats_bloc.dart';

abstract class AttendanceStatsEvent extends Equatable {
  const AttendanceStatsEvent();

  @override
  List<Object?> get props => [];
}

class LoadAttendanceStatsRequested extends AttendanceStatsEvent {
  final String sessionToken;
  final String? month; // Format: "YYYY-MM"

  const LoadAttendanceStatsRequested({
    required this.sessionToken,
    this.month,
  });

  @override
  List<Object?> get props => [sessionToken, month];
}
