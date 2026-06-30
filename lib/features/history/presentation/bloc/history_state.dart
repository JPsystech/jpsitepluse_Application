part of 'history_bloc.dart';

enum HistoryStatus {
  initial,
  loading,
  success,
  error,
  filtersLoading,
  filtersError,
  downloading,
  downloadSuccess,
  downloadError,
  detailLoading,
  detailSuccess,
  detailError
}

class HistoryState extends Equatable {
  final HistoryStatus status;
  final EngineerTimesheetListResponse? data;
  final String errorMessage;

  final List<String> clientOptions;
  final List<String> projectOptions;
  final List<String> siteOptions;

  final String? downloadedFileName;
  final String? downloadedFilePath;

  final EngineerTimesheetDetailResponse? detailData;

  const HistoryState({
    this.status = HistoryStatus.initial,
    this.data,
    this.errorMessage = '',
    this.clientOptions = const [],
    this.projectOptions = const [],
    this.siteOptions = const [],
    this.downloadedFileName,
    this.downloadedFilePath,
    this.detailData,
  });

  HistoryState copyWith({
    HistoryStatus? status,
    EngineerTimesheetListResponse? data,
    String? errorMessage,
    List<String>? clientOptions,
    List<String>? projectOptions,
    List<String>? siteOptions,
    String? downloadedFileName,
    String? downloadedFilePath,
    EngineerTimesheetDetailResponse? detailData,
  }) {
    return HistoryState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
      clientOptions: clientOptions ?? this.clientOptions,
      projectOptions: projectOptions ?? this.projectOptions,
      siteOptions: siteOptions ?? this.siteOptions,
      downloadedFileName: downloadedFileName ?? this.downloadedFileName,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      detailData: detailData ?? this.detailData,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        errorMessage,
        clientOptions,
        projectOptions,
        siteOptions,
        downloadedFileName,
        downloadedFilePath,
        detailData,
      ];
}
