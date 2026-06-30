part of 'history_bloc.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistoryRequested extends HistoryEvent {
  final String sessionToken;
  final String month;
  final String? startDate;
  final String? endDate;
  final String? selectedClient;
  final String? selectedProject;
  final String? selectedSite;

  const LoadHistoryRequested({
    required this.sessionToken,
    required this.month,
    this.startDate,
    this.endDate,
    this.selectedClient,
    this.selectedProject,
    this.selectedSite,
  });

  @override
  List<Object?> get props => [
        sessionToken,
        month,
        startDate,
        endDate,
        selectedClient,
        selectedProject,
        selectedSite,
      ];
}

class LoadHistoryFiltersRequested extends HistoryEvent {
  final String sessionToken;
  final String month;
  final String? startDate;
  final String? endDate;
  final String? selectedClient;
  final String? selectedProject;

  const LoadHistoryFiltersRequested({
    required this.sessionToken,
    required this.month,
    this.startDate,
    this.endDate,
    this.selectedClient,
    this.selectedProject,
  });

  @override
  List<Object?> get props => [
        sessionToken,
        month,
        startDate,
        endDate,
        selectedClient,
        selectedProject,
      ];
}

class DownloadHistoryPdfRequested extends HistoryEvent {
  final String sessionToken;
  final String month;
  final String? startDate;
  final String? endDate;
  final String? selectedClient;
  final String? selectedProject;
  final String? selectedSite;

  const DownloadHistoryPdfRequested({
    required this.sessionToken,
    required this.month,
    this.startDate,
    this.endDate,
    this.selectedClient,
    this.selectedProject,
    this.selectedSite,
  });

  @override
  List<Object?> get props => [
        sessionToken,
        month,
        startDate,
        endDate,
        selectedClient,
        selectedSite,
      ];
}

class LoadHistoryDetailRequested extends HistoryEvent {
  final String sessionToken;
  final String attendanceLogId;

  const LoadHistoryDetailRequested({
    required this.sessionToken,
    required this.attendanceLogId,
  });

  @override
  List<Object?> get props => [sessionToken, attendanceLogId];
}
