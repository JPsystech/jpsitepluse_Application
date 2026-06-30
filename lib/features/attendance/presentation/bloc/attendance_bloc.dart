import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sitepulse_engineer/features/attendance/data/models/punch_response_model.dart';
import 'package:sitepulse_engineer/features/attendance/data/repositories/attendance_repository.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceBloc({AttendanceRepository? repository})
      : _repository = repository ?? AttendanceRepository(),
        super(AttendanceInitial()) {
    on<PunchInRequested>(_onPunchInRequested);
    on<PunchOutRequested>(_onPunchOutRequested);
  }

  Future<({double lat, double lng, double accuracyM})> _resolveLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw "Location services are disabled";

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) throw "Location permission is required";
    if (perm == LocationPermission.deniedForever) {
      throw "Location permission is denied permanently.";
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return (lat: pos.latitude, lng: pos.longitude, accuracyM: pos.accuracy);
  }

  Future<void> _onPunchInRequested(PunchInRequested event, Emitter<AttendanceState> emit) async {
    emit(AttendanceLoading());
    try {
      double lat = event.lat ?? 0;
      double lng = event.lng ?? 0;
      double accuracyM = event.accuracyM ?? 0;

      if (event.lat == null || event.lng == null) {
        final loc = await _resolveLocation();
        lat = loc.lat;
        lng = loc.lng;
        accuracyM = loc.accuracyM;
      }

      final response = await _repository.punchIn(
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        exceptionReason: event.exceptionReason,
        projectId: event.projectId,
        clientPunchId: event.clientPunchId,
        clientPunchTimeIso: event.clientPunchTimeIso,
        isOffline: event.isOffline,
      );
      emit(PunchInSuccess(response: response));
    } catch (e) {
      emit(AttendanceError(message: e.toString()));
    }
  }

  Future<void> _onPunchOutRequested(PunchOutRequested event, Emitter<AttendanceState> emit) async {
    emit(AttendanceLoading());
    try {
      double lat = event.lat ?? 0;
      double lng = event.lng ?? 0;
      double accuracyM = event.accuracyM ?? 0;

      if (event.lat == null || event.lng == null) {
        final loc = await _resolveLocation();
        lat = loc.lat;
        lng = loc.lng;
        accuracyM = loc.accuracyM;
      }

      final response = await _repository.punchOut(
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        exceptionReason: event.exceptionReason,
        remarks: event.remarks,
        clientPunchId: event.clientPunchId,
        clientPunchTimeIso: event.clientPunchTimeIso,
        isOffline: event.isOffline,
      );
      emit(PunchOutSuccess(response: response));
    } catch (e) {
      emit(AttendanceError(message: e.toString()));
    }
  }
}
