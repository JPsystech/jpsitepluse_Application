import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sitepulse_engineer/shared/models/today_assignment.dart';
import 'package:sitepulse_engineer/features/history/data/services/history_service.dart';
import 'package:sitepulse_engineer/features/timesheet/data/services/timesheet_service.dart';

part 'history_event.dart';
part 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final TimesheetService _timesheetService;

  HistoryBloc({
    TimesheetService? timesheetService,
  })  : _timesheetService = timesheetService ?? TimesheetService(),
        super(const HistoryState()) {
    on<LoadHistoryRequested>(_onLoadHistoryRequested);
    on<LoadHistoryFiltersRequested>(_onLoadHistoryFiltersRequested);
    on<DownloadHistoryPdfRequested>(_onDownloadHistoryPdfRequested);
    on<LoadHistoryDetailRequested>(_onLoadHistoryDetailRequested);
  }

  Future<void> _onLoadHistoryFiltersRequested(
      LoadHistoryFiltersRequested event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(status: HistoryStatus.filtersLoading));
    try {
      final useMonth = event.month.trim().isNotEmpty;
      final resp = await _timesheetService.timesheetFilterOptions(
        token: event.sessionToken,
        month: useMonth ? event.month : null,
        startDate: useMonth ? null : event.startDate,
        endDate: useMonth ? null : event.endDate,
        client: event.selectedClient,
        project: event.selectedProject,
      );

      emit(state.copyWith(
        status: HistoryStatus.success, // Assuming we revert to success after fetching filters
        clientOptions: resp.clients,
        projectOptions: resp.projects,
        siteOptions: resp.sites,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HistoryStatus.filtersError,
        errorMessage: e.toString(),
        clientOptions: [],
        projectOptions: [],
        siteOptions: [],
      ));
    }
  }

  Future<void> _onLoadHistoryRequested(
      LoadHistoryRequested event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(status: HistoryStatus.loading));
    try {
      final useMonth = event.month.trim().isNotEmpty;
      final resp = await _timesheetService.timesheets(
        token: event.sessionToken,
        month: useMonth ? event.month : null,
        startDate: useMonth ? null : event.startDate,
        endDate: useMonth ? null : event.endDate,
        client: event.selectedClient,
        project: event.selectedProject,
        site: event.selectedSite,
        limit: 366,
      );
      emit(state.copyWith(status: HistoryStatus.success, data: resp));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.error, errorMessage: e.toString(), data: null));
    }
  }

  Future<void> _onDownloadHistoryPdfRequested(
      DownloadHistoryPdfRequested event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(status: HistoryStatus.downloading));
    try {
      final useMonth = event.month.trim().isNotEmpty;
      final resp = await _timesheetService.timesheetsPdf(
        token: event.sessionToken,
        month: useMonth ? event.month : null,
        startDate: useMonth ? null : event.startDate,
        endDate: useMonth ? null : event.endDate,
        client: event.selectedClient,
        project: event.selectedProject,
        site: event.selectedSite,
      );

      final dir = await getApplicationDocumentsDirectory();
      final safeName = resp.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File("${dir.path}/$safeName");
      await file.writeAsBytes(resp.bytes, flush: true);

      emit(state.copyWith(
        status: HistoryStatus.downloadSuccess,
        downloadedFileName: safeName,
        downloadedFilePath: file.path,
      ));
      
      // Reset back to success state so it can be triggered again
      emit(state.copyWith(status: HistoryStatus.success));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.downloadError, errorMessage: e.toString()));
      emit(state.copyWith(status: HistoryStatus.success));
    }
  }

  Future<void> _onLoadHistoryDetailRequested(
      LoadHistoryDetailRequested event, Emitter<HistoryState> emit) async {
    emit(state.copyWith(status: HistoryStatus.detailLoading));
    try {
      final resp = await _timesheetService.timesheetDetailByLog(
        token: event.sessionToken,
        attendanceLogId: event.attendanceLogId,
      );
      emit(state.copyWith(status: HistoryStatus.detailSuccess, detailData: resp));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.detailError, errorMessage: e.toString()));
    }
  }
}
