part of 'attendance_bloc.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class PunchInSuccess extends AttendanceState {
  final PunchInResponseModel response;
  const PunchInSuccess({required this.response});
  @override
  List<Object?> get props => [response];
}

class PunchOutSuccess extends AttendanceState {
  final PunchOutResponseModel response;
  const PunchOutSuccess({required this.response});
  @override
  List<Object?> get props => [response];
}

class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError({required this.message});
  @override
  List<Object?> get props => [message];
}
