import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:sitepulse_engineer/features/history/data/services/history_service.dart';
import 'package:sitepulse_engineer/features/timesheet/data/services/timesheet_service.dart';
import 'package:sitepulse_engineer/shared/models/today_assignment.dart';

part 'timeline_event.dart';
part 'timeline_state.dart';

class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  final HistoryService _historyService;
  final TimesheetService _timesheetService;

  TimelineBloc({
    HistoryService? historyService,
    TimesheetService? timesheetService,
  })  : _historyService = historyService ?? HistoryService(),
        _timesheetService = timesheetService ?? TimesheetService(),
        super(const TimelineState()) {
    on<LoadTimelineRequested>(_onLoadTimelineRequested);
    on<FilterTimelineRequested>(_onFilterTimelineRequested);
    on<DownloadTimelinePdfRequested>(_onDownloadTimelinePdfRequested);
  }

  Future<void> _onLoadTimelineRequested(
      LoadTimelineRequested event, Emitter<TimelineState> emit) async {
    emit(state.copyWith(status: TimelineStatus.loading, month: event.month));
    try {
      final resp = await _historyService.history(
        token: event.sessionToken,
        month: event.month.trim().isEmpty ? null : event.month,
      );
      emit(state.copyWith(
        status: TimelineStatus.loaded,
        data: resp,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TimelineStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onFilterTimelineRequested(
      FilterTimelineRequested event, Emitter<TimelineState> emit) {
    emit(state.copyWith(statusFilter: event.statusFilter));
  }

  Future<void> _onDownloadTimelinePdfRequested(
      DownloadTimelinePdfRequested event, Emitter<TimelineState> emit) async {
    emit(state.copyWith(status: TimelineStatus.downloading));
    try {
      final resp = await _timesheetService.timesheetsPdf(
        token: event.sessionToken,
        month: event.month.trim().isEmpty ? null : event.month,
      );
      
      final dir = await getApplicationDocumentsDirectory();
      final safeName = resp.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
      final file = File("${dir.path}/$safeName");
      await file.writeAsBytes(resp.bytes, flush: true);

      emit(state.copyWith(
        status: TimelineStatus.downloadSuccess,
        downloadedFileName: safeName,
        downloadedFilePath: file.path,
      ));
      
      // Reset back to loaded
      emit(state.copyWith(status: TimelineStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: TimelineStatus.error,
        errorMessage: e.toString(),
      ));
      // Reset back to loaded
      emit(state.copyWith(status: TimelineStatus.loaded));
    }
  }
}
