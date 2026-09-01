import "dart:io";
import "package:sitepulse_engineer/features/documents/data/services/documents_service.dart";
import "package:sitepulse_engineer/core/storage/offline_sync_store.dart";
import 'package:sitepulse_engineer/core/error/error_handler.dart';

class OfflineDocumentSyncService {
  OfflineDocumentSyncService({DocumentsService? documentsService})
      : documentsService = documentsService ?? DocumentsService();

  final DocumentsService documentsService;

  static bool _isSyncing = false;

  Future<int> sync({required String token}) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;
    try {
      final items = await OfflineSyncStore.getDocumentQueue();
      for (final doc in items) {
        try {
          final filePath = doc['local_file_path'];
          final file = File(filePath);
          if (!(await file.exists())) {
            // File is lost, remove from queue
            await OfflineSyncStore.removeDocumentFromQueue(filePath);
            continue;
          }

          final bytes = await file.readAsBytes();
          
          await documentsService.uploadDocumentBytes(
            token: token,
            documentType: doc['document_type'],
            documentName: doc['document_name'],
            bytes: bytes,
            originalFileName: doc['original_filename'],
            contentType: doc['content_type'],
            sizeBytes: doc['size_bytes'],
            fileExtension: doc['file_extension'],
          );

          await OfflineSyncStore.removeDocumentFromQueue(filePath);
          synced += 1;
        } catch (e) {
          final isOffline = ErrorHandler.isOfflineError(e);
          if (isOffline) {
            break; // Network dropped again, stop syncing
          } else {
             // If it's another error (e.g., 400 Bad Request), remove it so it doesn't block
             await OfflineSyncStore.removeDocumentFromQueue(doc['local_file_path']);
          }
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }
}
