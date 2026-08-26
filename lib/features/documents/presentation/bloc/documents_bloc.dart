import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitepulse_engineer/features/documents/data/services/documents_service.dart';
import 'package:sitepulse_engineer/shared/models/engineer_document_model.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/storage/offline_sync_store.dart';
import 'package:sitepulse_engineer/core/services/api_client.dart';

part 'documents_event.dart';
part 'documents_state.dart';

class DocumentsBloc extends Bloc<DocumentsEvent, DocumentsState> {
  final DocumentsService _documentService;

  DocumentsBloc({DocumentsService? documentService})
      : _documentService = documentService ?? DocumentsService(),
        super(const DocumentsState()) {
    on<LoadDocumentsRequested>(_onLoadDocumentsRequested);
    on<UploadDocumentRequested>(_onUploadDocumentRequested);
    on<ViewDocumentRequested>(_onViewDocumentRequested);
  }

  String? get _ndtExpiryKey {
    final engineerId = (SessionStore.current?.engineer.id ?? "").trim();
    if (engineerId.isEmpty) return null;
    return "sitepulse_ndt_expiry_$engineerId";
  }

  Future<DateTime?> _loadNdtExpiryDate() async {
    final key = _ndtExpiryKey;
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _saveNdtExpiryDate(DateTime date) async {
    final key = _ndtExpiryKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key, DateTime(date.year, date.month, date.day).toIso8601String());
  }

  String _friendlyUploadError(String message) {
    final cleaned = message.replaceFirst("Exception: ", "").trim();
    final lower = cleaned.toLowerCase();
    if (lower.contains("too large")) {
      return "File size too large. Please upload a file smaller than 15 MB.";
    }
    if (lower.contains("unsupported") ||
        lower.contains("only jpg") ||
        lower.contains("only png")) {
      return "Unsupported format. Please select an allowed document format.";
    }
    if (lower.contains("network") || 
        lower.contains("unreachable") || 
        lower.contains("connection failed") || 
        lower.contains("socketexception") || 
        lower.contains("failed host lookup")) {
      return "You must be online to perform this action.";
    }
    return cleaned.isEmpty ? "Upload failed. Please try again." : cleaned;
  }

  Future<void> _onLoadDocumentsRequested(
      LoadDocumentsRequested event, Emitter<DocumentsState> emit) async {
    if (event.showLoader) {
      emit(state.copyWith(
          status: DocumentsStatus.loading,
          errorMessage: "",
          clearOneOffs: true));
    }

    try {
      final ndtDate = await _loadNdtExpiryDate();
      final docs =
          await _documentService.listDocuments(token: event.sessionToken);

      // Merge with offline queue
      final offlineDocs = await OfflineSyncStore.getDocumentQueue();
      for (var offlineDoc in offlineDocs) {
        final docType = offlineDoc['document_type'];
        final index = docs.indexWhere((d) => d.documentType == docType);
        if (index != -1) {
          final existing = docs[index];
          docs[index] = EngineerDocument(
            id: existing.id,
            engineerId: existing.engineerId,
            documentType: existing.documentType,
            documentName: existing.documentName,
            fileUrl: offlineDoc['local_file_path'], // trick UI into using local file path
            originalFilename: offlineDoc['original_filename'],
            contentType: existing.contentType,
            sizeBytes: existing.sizeBytes,
            verificationStatus: "pending",
            adminRemarks: existing.adminRemarks,
            isRequired: existing.isRequired,
            requiredLabel: existing.requiredLabel,
            uploadedAt: existing.uploadedAt,
            updatedAt: existing.updatedAt,
          );
        } else {
          docs.add(EngineerDocument(
            id: "-1",
            engineerId: "",
            documentType: docType,
            documentName: offlineDoc['document_name'] ?? docType,
            fileUrl: offlineDoc['local_file_path'],
            originalFilename: offlineDoc['original_filename'],
            contentType: offlineDoc['content_type'] ?? "application/pdf",
            sizeBytes: offlineDoc['size_bytes'] ?? 0,
            verificationStatus: "pending",
            adminRemarks: null,
            isRequired: false,
            requiredLabel: null,
            uploadedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }

      emit(state.copyWith(
        status: DocumentsStatus.loaded,
        documents: docs,
        ndtExpiryDate: ndtDate,
        clearOneOffs: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DocumentsStatus.error,
        errorMessage: e.toString(),
        clearOneOffs: true,
      ));
    }
  }

  Future<void> _onUploadDocumentRequested(
      UploadDocumentRequested event, Emitter<DocumentsState> emit) async {
    if (state.busyKeys.contains(event.busyKey)) return;

    final newBusyKeys = Set<String>.from(state.busyKeys)..add(event.busyKey);
    emit(state.copyWith(busyKeys: newBusyKeys, clearOneOffs: true));

    try {
      final doc = await _documentService.uploadDocumentBytes(
        token: event.sessionToken,
        documentType: event.documentType,
        documentName: event.documentName,
        bytes: event.bytes,
        originalFileName: event.originalFileName,
        contentType: event.contentType,
        sizeBytes: event.sizeBytes,
        fileExtension: event.fileExtension,
      );

      // Auto-cache the file for offline viewing
      final tempDir = await getTemporaryDirectory();
      final name = doc.effectiveFileName.isEmpty
          ? "document_${doc.id}.pdf"
          : doc.effectiveFileName;
      final safeName = name
          .replaceAll("\\", "_")
          .replaceAll("/", "_")
          .replaceAll(":", "_")
          .replaceAll("*", "_")
          .replaceAll("?", "_")
          .replaceAll("\"", "_")
          .replaceAll("<", "_")
          .replaceAll(">", "_")
          .replaceAll("|", "_");
      final file = File("${tempDir.path}${Platform.pathSeparator}$safeName");
      await file.writeAsBytes(event.bytes, flush: true);

      DateTime? newNdtDate = state.ndtExpiryDate;
      if (event.documentType == "ndt" && event.ndtExpiryDate != null) {
        await _saveNdtExpiryDate(event.ndtExpiryDate!);
        newNdtDate = DateTime(event.ndtExpiryDate!.year,
            event.ndtExpiryDate!.month, event.ndtExpiryDate!.day);
      }

      // Automatically reload documents after success
      final docs =
          await _documentService.listDocuments(token: event.sessionToken);

      final updatedBusyKeys = Set<String>.from(state.busyKeys)
        ..remove(event.busyKey);

      emit(state.copyWith(
        documents: docs,
        busyKeys: updatedBusyKeys,
        ndtExpiryDate: newNdtDate,
        snackbarMessage: "Document uploaded successfully",
        isErrorSnackbar: false,
        clearOneOffs: false,
      ));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isOffline = errStr.contains('connection failed') || 
                        errStr.contains('socketexception') || 
                        errStr.contains('failed host lookup') || 
                        errStr.contains('network is unreachable');
      
      final updatedBusyKeys = Set<String>.from(state.busyKeys)
        ..remove(event.busyKey);

      if (isOffline) {
        try {
          // Save file locally
          final tempDir = await getApplicationDocumentsDirectory();
          final safeName = "offline_upload_${DateTime.now().millisecondsSinceEpoch}_${event.originalFileName}";
          final file = File("${tempDir.path}${Platform.pathSeparator}$safeName");
          await file.writeAsBytes(event.bytes, flush: true);

          // Queue upload
          await OfflineSyncStore.queueDocumentUpload({
            "document_type": event.documentType,
            "document_name": event.documentName,
            "original_filename": event.originalFileName,
            "content_type": event.contentType,
            "size_bytes": event.sizeBytes,
            "file_extension": event.fileExtension,
            "ndt_expiry_date": event.ndtExpiryDate?.toIso8601String(),
            "local_file_path": file.path,
          });

          DateTime? newNdtDate = state.ndtExpiryDate;
          if (event.documentType == "ndt" && event.ndtExpiryDate != null) {
            await _saveNdtExpiryDate(event.ndtExpiryDate!);
            newNdtDate = DateTime(event.ndtExpiryDate!.year,
                event.ndtExpiryDate!.month, event.ndtExpiryDate!.day);
          }

          emit(state.copyWith(
            busyKeys: updatedBusyKeys,
            ndtExpiryDate: newNdtDate,
            snackbarMessage: "Document queued for offline upload",
            isErrorSnackbar: false,
            clearOneOffs: false,
          ));
          return;
        } catch (queueError) {
          // If queueing fails, fallback to standard error handling
        }
      }

      final msg = _friendlyUploadError(e.toString());

      emit(state.copyWith(
        busyKeys: updatedBusyKeys,
        snackbarMessage: msg,
        isErrorSnackbar: true,
        clearOneOffs: false,
      ));
    }
  }

  bool _isImageDocument(EngineerDocument doc) {
    final ct = doc.contentType.trim().toLowerCase();
    if (ct.startsWith("image/")) return true;
    final ext = doc.effectiveFileName.split('.').last.toLowerCase();
    return ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "webp";
  }

  Future<void> _onViewDocumentRequested(
      ViewDocumentRequested event, Emitter<DocumentsState> emit) async {
    if (state.busyKeys.contains(event.busyKey)) return;

    final newBusyKeys = Set<String>.from(state.busyKeys)..add(event.busyKey);
    emit(state.copyWith(busyKeys: newBusyKeys, clearOneOffs: true));

    try {
      final url = event.document.fileUrl.trim();
      final isImage = _isImageDocument(event.document);
      
      // If it's an offline queued document, the URL is actually a local file path
      if (File(url).existsSync()) {
        final updatedBusyKeys = Set<String>.from(state.busyKeys)..remove(event.busyKey);
        emit(state.copyWith(
          busyKeys: updatedBusyKeys,
          downloadedFilePath: url,
          isImageDownloaded: isImage,
          clearOneOffs: false,
        ));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final name = event.document.effectiveFileName.isEmpty
          ? "document_${event.document.id}.pdf"
          : event.document.effectiveFileName;
      final safeName = name
          .replaceAll("\\", "_")
          .replaceAll("/", "_")
          .replaceAll(":", "_")
          .replaceAll("*", "_")
          .replaceAll("?", "_")
          .replaceAll("\"", "_")
          .replaceAll("<", "_")
          .replaceAll(">", "_")
          .replaceAll("|", "_");

      final file = File("${tempDir.path}${Platform.pathSeparator}$safeName");
      
      // If the file already exists locally, use the cached version directly
      if (!(await file.exists())) {
        final apiUri = await ApiClient().url(url);
        final response = await http.get(apiUri);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw "Failed to download file";
        }
        await file.writeAsBytes(response.bodyBytes, flush: true);
      }

      final updatedBusyKeys = Set<String>.from(state.busyKeys)
        ..remove(event.busyKey);

      emit(state.copyWith(
        busyKeys: updatedBusyKeys,
        downloadedFilePath: file.path,
        isImageDownloaded: isImage,
        clearOneOffs: false,
      ));
    } catch (e) {
      final updatedBusyKeys = Set<String>.from(state.busyKeys)
        ..remove(event.busyKey);

      emit(state.copyWith(
        busyKeys: updatedBusyKeys,
        snackbarMessage:
            "Unable to open file. ${_friendlyUploadError(e.toString())}",
        isErrorSnackbar: true,
        clearOneOffs: false,
      ));
    }
  }
}
