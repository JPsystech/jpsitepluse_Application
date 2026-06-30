part of 'documents_bloc.dart';

abstract class DocumentsEvent extends Equatable {
  const DocumentsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDocumentsRequested extends DocumentsEvent {
  final String sessionToken;
  final bool showLoader;

  const LoadDocumentsRequested({required this.sessionToken, this.showLoader = true});

  @override
  List<Object?> get props => [sessionToken, showLoader];
}

class UploadDocumentRequested extends DocumentsEvent {
  final String sessionToken;
  final String documentType;
  final String documentName;
  final Uint8List bytes;
  final String originalFileName;
  final String contentType;
  final int sizeBytes;
  final String fileExtension;
  final DateTime? ndtExpiryDate;
  final String busyKey;

  const UploadDocumentRequested({
    required this.sessionToken,
    required this.documentType,
    required this.documentName,
    required this.bytes,
    required this.originalFileName,
    required this.contentType,
    required this.sizeBytes,
    required this.fileExtension,
    this.ndtExpiryDate,
    required this.busyKey,
  });

  @override
  List<Object?> get props => [
        sessionToken,
        documentType,
        documentName,
        bytes,
        originalFileName,
        contentType,
        sizeBytes,
        fileExtension,
        ndtExpiryDate,
        busyKey,
      ];
}

class ViewDocumentRequested extends DocumentsEvent {
  final EngineerDocument document;
  final String busyKey;

  const ViewDocumentRequested({required this.document, required this.busyKey});

  @override
  List<Object?> get props => [document, busyKey];
}
