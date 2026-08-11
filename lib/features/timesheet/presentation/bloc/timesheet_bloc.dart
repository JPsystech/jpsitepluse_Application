import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:sitepulse_engineer/core/services/offline_timesheet_queue.dart';
import 'package:sitepulse_engineer/features/home/data/services/home_service.dart';
import 'package:sitepulse_engineer/features/timesheet/data/services/site_photo_service.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';

part 'timesheet_event.dart';
part 'timesheet_state.dart';

class TimesheetBloc extends Bloc<TimesheetEvent, TimesheetState> {
  final HomeService _homeService;
  final SitePhotoService _sitePhotoService;

  TimesheetBloc({
    HomeService? homeService,
    SitePhotoService? sitePhotoService,
  })  : _homeService = homeService ?? HomeService(),
        _sitePhotoService = sitePhotoService ?? SitePhotoService(),
        super(const TimesheetState()) {
    on<LoadTimesheetDataRequested>(_onLoadTimesheetDataRequested);
    on<SubmitTimesheetRequested>(_onSubmitTimesheetRequested);
  }

  Future<void> _onLoadTimesheetDataRequested(
      LoadTimesheetDataRequested event, Emitter<TimesheetState> emit) async {
    emit(state.copyWith(status: TimesheetStatus.loading));
    try {
      final resp = await _homeService.getTodayAssignments();
      TodayAssignmentModel? a;
      if (resp.assignments.isNotEmpty) {
        final activePid = (resp.activeProjectId ?? "").trim();
        if (activePid.isNotEmpty) {
          a = resp.assignments.firstWhere((x) => x.projectId == activePid,
              orElse: () => resp.assignments.first);
        } else {
          a = resp.assignments.first;
        }
      }
      emit(state.copyWith(
        status: TimesheetStatus.loaded,
        projectName: a?.projectName ?? "-",
        siteName: a?.siteName ?? "-",
        projectId: a?.projectId ?? "",
        attendanceLogId: resp.activeAttendanceLogId ?? "",
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TimesheetStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitTimesheetRequested(
      SubmitTimesheetRequested event, Emitter<TimesheetState> emit) async {
    emit(state.copyWith(status: TimesheetStatus.submitting));
    try {
      final hoursText =
          (event.minutes / 60).toStringAsFixed(event.minutes % 60 == 0 ? 0 : 1);
      final addressText =
          "${event.activityType} • ${hoursText}h • ${event.description}";

      final fileUrl = await _sitePhotoService.uploadProgressPhoto(
        token: event.sessionToken,
        file: event.photo,
        lat: event.lat,
        lng: event.lng,
        addressText: addressText,
        projectName: state.projectName.trim().isEmpty ? "-" : state.projectName,
        siteName: state.siteName.trim().isEmpty ? "-" : state.siteName,
        projectId: state.projectId.trim().isEmpty ? null : state.projectId,
        attendanceLogId: state.attendanceLogId.trim().isEmpty ? null : state.attendanceLogId,
        empCode:
            event.engineerEmpCode.trim().isEmpty ? "-" : event.engineerEmpCode,
        capturedAt: DateTime.now(),
      );

      emit(state.copyWith(
        status: TimesheetStatus.submitSuccess,
        uploadedPhotoUrl: fileUrl,
      ));

      // Reset status to loaded for future submissions
      emit(state.copyWith(status: TimesheetStatus.loaded));
    } catch (e) {
      final err = e.toString().toLowerCase();
      final isOffline = err.contains('connection failed') || err.contains('socketexception') || err.contains('failed host lookup') || err.contains('network is unreachable');
      if (isOffline) {
        // Network error - queue offline
        final hoursText = (event.minutes / 60).toStringAsFixed(event.minutes % 60 == 0 ? 0 : 1);
        final addressText = "${event.activityType} • ${hoursText}h • ${event.description}";
        
        await OfflineTimesheetQueue().add(OfflineTimesheet(
          id: const Uuid().v4(),
          photoPath: event.photo.path,
          lat: event.lat,
          lng: event.lng,
          addressText: addressText,
          projectName: state.projectName.trim().isEmpty ? "-" : state.projectName,
          siteName: state.siteName.trim().isEmpty ? "-" : state.siteName,
          projectId: state.projectId.trim().isEmpty ? null : state.projectId,
          attendanceLogId: state.attendanceLogId.trim().isEmpty ? null : state.attendanceLogId,
          empCode: event.engineerEmpCode.trim().isEmpty ? "-" : event.engineerEmpCode,
          capturedAtIso: DateTime.now().toIso8601String(),
        ));

        emit(state.copyWith(
          status: TimesheetStatus.submitSuccess,
          uploadedPhotoUrl: "offline_queued",
        ));
      } else {
        emit(state.copyWith(
          status: TimesheetStatus.error,
          errorMessage: e.toString(),
        ));
      }

      // Revert status to loaded
      emit(state.copyWith(status: TimesheetStatus.loaded));
    }
  }
}

