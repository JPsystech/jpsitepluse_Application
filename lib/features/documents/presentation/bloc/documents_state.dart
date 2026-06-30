part of 'documents_bloc.dart';

enum DocumentsStatus { initial, loading, loaded, error }

class DocumentsState extends Equatable {
  final DocumentsStatus status;
  final List<EngineerDocument> documents;
  final Set<String> busyKeys;
  final DateTime? ndtExpiryDate;
  final String errorMessage;

  // For one-off events
  final String? downloadedFilePath;
  final String? snackbarMessage;
  final bool isErrorSnackbar;

  const DocumentsState({
    this.status = DocumentsStatus.initial,
    this.documents = const [],
    this.busyKeys = const {},
    this.ndtExpiryDate,
    this.errorMessage = "",
    this.downloadedFilePath,
    this.snackbarMessage,
    this.isErrorSnackbar = false,
  });

  DocumentsState copyWith({
    DocumentsStatus? status,
    List<EngineerDocument>? documents,
    Set<String>? busyKeys,
    DateTime? ndtExpiryDate,
    String? errorMessage,
    String? downloadedFilePath,
    String? snackbarMessage,
    bool? isErrorSnackbar,
    bool clearOneOffs = false,
  }) {
    return DocumentsState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      busyKeys: busyKeys ?? this.busyKeys,
      ndtExpiryDate: ndtExpiryDate ?? this.ndtExpiryDate,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadedFilePath:
          clearOneOffs ? null : (downloadedFilePath ?? this.downloadedFilePath),
      snackbarMessage:
          clearOneOffs ? null : (snackbarMessage ?? this.snackbarMessage),
      isErrorSnackbar:
          clearOneOffs ? false : (isErrorSnackbar ?? this.isErrorSnackbar),
    );
  }

  @override
  List<Object?> get props => [
        status,
        documents,
        busyKeys,
        ndtExpiryDate,
        errorMessage,
        downloadedFilePath,
        snackbarMessage,
        isErrorSnackbar,
      ];
}
