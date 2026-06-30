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
    if (lower.contains("network") || lower.contains("unreachable")) {
      return "Internet/API error. Please check your connection and retry.";
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
      await _documentService.uploadDocumentBytes(
        token: event.sessionToken,
        documentType: event.documentType,
        documentName: event.documentName,
        bytes: event.bytes,
        originalFileName: event.originalFileName,
        contentType: event.contentType,
        sizeBytes: event.sizeBytes,
        fileExtension: event.fileExtension,
      );

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
      final updatedBusyKeys = Set<String>.from(state.busyKeys)
        ..remove(event.busyKey);
      final msg = _friendlyUploadError(e.toString());

      emit(state.copyWith(
        busyKeys: updatedBusyKeys,
        snackbarMessage: msg,
        isErrorSnackbar: true,
        clearOneOffs: false,
      ));
    }
  }

  Future<void> _onViewDocumentRequested(
      ViewDocumentRequested event, Emitter<DocumentsState> emit) async {
    if (state.busyKeys.contains(event.busyKey)) return;

    final newBusyKeys = Set<String>.from(state.busyKeys)..add(event.busyKey);
    emit(state.copyWith(busyKeys: newBusyKeys, clearOneOffs: true));

    try {
      final url = event.document.fileUrl.trim();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw "Failed to download file";
      }

      final tempDir = await getTemporaryDirectory();
      final name = event.document.effectiveFileName.isEmpty
          ? "document.pdf"
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
      await file.writeAsBytes(response.bodyBytes, flush: true);

      final updatedBusyKeys = Set<String>.from(state.busyKeys)
        ..remove(event.busyKey);

      emit(state.copyWith(
        busyKeys: updatedBusyKeys,
        downloadedFilePath: file.path,
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
