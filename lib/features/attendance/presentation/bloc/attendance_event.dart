part of 'attendance_bloc.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();
  @override
  List<Object?> get props => [];
}

class PunchInRequested extends AttendanceEvent {
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? exceptionReason;
  final double? siteLat;
  final double? siteLng;
  final double? allowedRadiusM;
  final String? projectId;
  final String? clientPunchId;
  final String? clientPunchTimeIso;
  final bool? isOffline;

  const PunchInRequested({
    this.lat,
    this.lng,
    this.accuracyM,
    this.exceptionReason,
    this.siteLat,
    this.siteLng,
    this.allowedRadiusM,
    this.projectId,
    this.clientPunchId,
    this.clientPunchTimeIso,
    this.isOffline,
  });

  @override
  List<Object?> get props => [
        lat,
        lng,
        accuracyM,
        exceptionReason,
        siteLat,
        siteLng,
        allowedRadiusM,
        projectId,
        clientPunchId,
        clientPunchTimeIso,
        isOffline,
      ];
}

class PunchOutRequested extends AttendanceEvent {
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? exceptionReason;
  final double? siteLat;
  final double? siteLng;
  final double? allowedRadiusM;
  final String remarks;
  final String? clientPunchId;
  final String? clientPunchTimeIso;
  final bool? isOffline;

  const PunchOutRequested({
    this.lat,
    this.lng,
    this.accuracyM,
    this.exceptionReason,
    this.siteLat,
    this.siteLng,
    this.allowedRadiusM,
    required this.remarks,
    this.clientPunchId,
    this.clientPunchTimeIso,
    this.isOffline,
  });

  @override
  List<Object?> get props => [
        lat,
        lng,
        accuracyM,
        exceptionReason,
        siteLat,
        siteLng,
        allowedRadiusM,
        remarks,
        clientPunchId,
        clientPunchTimeIso,
        isOffline,
      ];
}

