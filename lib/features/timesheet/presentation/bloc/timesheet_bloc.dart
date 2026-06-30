import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

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
      final hoursText = (event.minutes / 60).toStringAsFixed(event.minutes % 60 == 0 ? 0 : 1);
      final addressText = "${event.activityType} • ${hoursText}h • ${event.description}";

      final fileUrl = await _sitePhotoService.uploadProgressPhoto(
        token: event.sessionToken,
        file: event.photo,
        lat: event.lat,
        lng: event.lng,
        addressText: addressText,
        projectName: state.projectName.trim().isEmpty ? "-" : state.projectName,
        siteName: state.siteName.trim().isEmpty ? "-" : state.siteName,
        empCode: event.engineerEmpCode.trim().isEmpty ? "-" : event.engineerEmpCode,
        capturedAt: DateTime.now(),
      );

      emit(state.copyWith(
        status: TimesheetStatus.submitSuccess,
        uploadedPhotoUrl: fileUrl,
      ));
      
      // Reset status to loaded for future submissions
      emit(state.copyWith(status: TimesheetStatus.loaded));
      
    } catch (e) {
      emit(state.copyWith(
        status: TimesheetStatus.error,
        errorMessage: e.toString(),
      ));
      
      // Revert status to loaded
      emit(state.copyWith(status: TimesheetStatus.loaded));
    }
  }
}
