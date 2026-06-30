part of 'timesheet_bloc.dart';

abstract class TimesheetEvent extends Equatable {
  const TimesheetEvent();
  @override
  List<Object?> get props => [];
}

class LoadTimesheetDataRequested extends TimesheetEvent {
  final String sessionToken;
  const LoadTimesheetDataRequested({required this.sessionToken});
  @override
  List<Object?> get props => [sessionToken];
}

class SubmitTimesheetRequested extends TimesheetEvent {
  final String sessionToken;
  final String engineerEmpCode;
  final File photo;
  final String description;
  final int minutes;
  final String activityType;
  final double lat;
  final double lng;

  const SubmitTimesheetRequested({
    required this.sessionToken,
    required this.engineerEmpCode,
    required this.photo,
    required this.description,
    required this.minutes,
    required this.activityType,
    required this.lat,
    required this.lng,
  });

  @override
  List<Object?> get props => [
        sessionToken,
        engineerEmpCode,
        photo.path,
        description,
        minutes,
        activityType,
        lat,
        lng,
      ];
}
