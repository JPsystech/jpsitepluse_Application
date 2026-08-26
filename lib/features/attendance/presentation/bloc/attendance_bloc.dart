import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sitepulse_engineer/features/attendance/data/models/punch_response_model.dart';
import 'package:sitepulse_engineer/features/attendance/data/repositories/attendance_repository.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:sitepulse_engineer/core/services/offline_punch_queue.dart';

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

  Future<({double lat, double lng, double accuracyM})>
      _resolveLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw "Location services are disabled";
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw "Location permission is required";
    }
    if (perm == LocationPermission.deniedForever) {
      throw "Location permission is denied permanently.";
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (pos.isMocked) {
      throw "Fake GPS detected. Please disable mock locations to punch in.";
    }

    try {
      if (!kDebugMode) {
        final isDevMode = await SafeDevice.isDevelopmentModeEnable;
        if (isDevMode) {
          throw "Developer Options must be disabled to punch in. Please turn off Developer Options in your phone settings to ensure location integrity.";
        }
      }
    } catch (_) {
      // SafeDevice might throw on unsupported platforms, ignore
    }

    return (lat: pos.latitude, lng: pos.longitude, accuracyM: pos.accuracy);
  }

  Future<({double lat, double lng, double accuracyM})>
      resolveLocationPublic() => _resolveLocation();

  Future<void> _onPunchInRequested(
      PunchInRequested event, Emitter<AttendanceState> emit) async {
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

      if (event.exceptionReason == null && event.siteLat != null && event.siteLng != null && event.allowedRadiusM != null) {
        final distance = Geolocator.distanceBetween(lat, lng, event.siteLat!, event.siteLng!);
        if (distance > event.allowedRadiusM!) {
          throw 'OUT_OF_RADIUS_REASON_REQUIRED';
        }
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
      final err = e.toString().toLowerCase();
      final isOffline = err.contains('connection failed') || err.contains('socketexception') || err.contains('failed host lookup') || err.contains('network is unreachable');
      if (isOffline) {
        final loc = await resolveLocationPublic().catchError((_) => (lat: 0.0, lng: 0.0, accuracyM: 0.0));
        await OfflinePunchQueue().add(OfflinePunch(
          clientPunchId: event.clientPunchId ?? const Uuid().v4(),
          type: OfflinePunchType.inPunch,
          clientPunchTimeIso: event.clientPunchTimeIso ?? DateTime.now().toUtc().toIso8601String(),
          lat: event.lat ?? loc.lat,
          lng: event.lng ?? loc.lng,
          accuracyM: event.accuracyM ?? loc.accuracyM,
          projectId: event.projectId,
          exceptionReason: event.exceptionReason,
        ));
        emit(const PunchOfflineQueued());
      } else {
        emit(AttendanceError(message: e.toString()));
      }
    }
  }

  Future<void> _onPunchOutRequested(
      PunchOutRequested event, Emitter<AttendanceState> emit) async {
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

      if (event.exceptionReason == null && event.siteLat != null && event.siteLng != null && event.allowedRadiusM != null) {
        final distance = Geolocator.distanceBetween(lat, lng, event.siteLat!, event.siteLng!);
        if (distance > event.allowedRadiusM!) {
          throw 'OUT_OF_RADIUS_REASON_REQUIRED';
        }
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
      final err = e.toString().toLowerCase();
      final isOffline = err.contains('connection failed') || err.contains('socketexception') || err.contains('failed host lookup') || err.contains('network is unreachable');
      if (isOffline) {
        final loc = await resolveLocationPublic().catchError((_) => (lat: 0.0, lng: 0.0, accuracyM: 0.0));
        await OfflinePunchQueue().add(OfflinePunch(
          clientPunchId: event.clientPunchId ?? const Uuid().v4(),
          type: OfflinePunchType.outPunch,
          clientPunchTimeIso: event.clientPunchTimeIso ?? DateTime.now().toUtc().toIso8601String(),
          lat: event.lat ?? loc.lat,
          lng: event.lng ?? loc.lng,
          accuracyM: event.accuracyM ?? loc.accuracyM,
          remarks: event.remarks,
          exceptionReason: event.exceptionReason,
        ));
        emit(const PunchOfflineQueued());
      } else {
        emit(AttendanceError(message: e.toString()));
      }
    }
  }
}

