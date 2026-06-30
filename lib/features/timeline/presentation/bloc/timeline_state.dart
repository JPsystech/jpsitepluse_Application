part of 'timeline_bloc.dart';

enum TimelineStatus { initial, loading, loaded, downloading, downloadSuccess, error }

class TimelineState extends Equatable {
  final TimelineStatus status;
  final EngineerHistoryResponse? data;
  final String month;
  final String statusFilter;
  final String errorMessage;
  final String? downloadedFileName;
  final String? downloadedFilePath;

  const TimelineState({
    this.status = TimelineStatus.initial,
    this.data,
    this.month = "",
    this.statusFilter = "ALL",
    this.errorMessage = "",
    this.downloadedFileName,
    this.downloadedFilePath,
  });

  TimelineState copyWith({
    TimelineStatus? status,
    EngineerHistoryResponse? data,
    String? month,
    String? statusFilter,
    String? errorMessage,
    String? downloadedFileName,
    String? downloadedFilePath,
  }) {
    return TimelineState(
      status: status ?? this.status,
      data: data ?? this.data,
      month: month ?? this.month,
      statusFilter: statusFilter ?? this.statusFilter,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadedFileName: downloadedFileName ?? this.downloadedFileName,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        month,
        statusFilter,
        errorMessage,
        downloadedFileName,
        downloadedFilePath,
      ];
}
