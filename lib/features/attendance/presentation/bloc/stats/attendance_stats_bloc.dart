import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:sitepulse_engineer/shared/models/today_assignment.dart';
import 'package:sitepulse_engineer/features/timesheet/data/services/timesheet_service.dart';

part 'attendance_stats_event.dart';
part 'attendance_stats_state.dart';

class AttendanceStatsBloc extends Bloc<AttendanceStatsEvent, AttendanceStatsState> {
  final TimesheetService _timesheetService;

  AttendanceStatsBloc({
    TimesheetService? timesheetService,
  })  : _timesheetService = timesheetService ?? TimesheetService(),
        super(const AttendanceStatsState()) {
    on<LoadAttendanceStatsRequested>(_onLoadAttendanceStatsRequested);
  }

  Future<void> _onLoadAttendanceStatsRequested(
      LoadAttendanceStatsRequested event, Emitter<AttendanceStatsState> emit) async {
    emit(state.copyWith(status: AttendanceStatsStatus.loading));
    try {
      final resp = await _timesheetService.timesheets(
        token: event.sessionToken,
        month: event.month,
      );
      emit(state.copyWith(status: AttendanceStatsStatus.success, data: resp));
    } catch (e) {
      emit(state.copyWith(
          status: AttendanceStatsStatus.error, errorMessage: e.toString()));
    }
  }
}
