import "dart:io";
import "dart:typed_data";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:image_picker/image_picker.dart";
import "package:open_filex/open_filex.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/shared/models/engineer_document_model.dart";
import "package:sitepulse_engineer/features/documents/data/services/documents_service.dart";
import "package:sitepulse_engineer/shared/widgets/image_viewer.dart";
import "package:sitepulse_engineer/shared/widgets/status_chip.dart";
import "package:sitepulse_engineer/features/documents/presentation/bloc/documents_bloc.dart";
import "package:sitepulse_engineer/core/error/error_handler.dart";

import "../../../../core/theme/app_colors_extension.dart";

class DocumentUploadScreen extends StatelessWidget {
  final DocumentsBloc? bloc;

  const DocumentUploadScreen({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: const _DocumentUploadView(),
      );
    }
    try {
      final existing = context.read<DocumentsBloc>();
      return BlocProvider.value(
        value: existing,
        child: const _DocumentUploadView(),
      );
    } catch (_) {
      return BlocProvider(
        create: (_) => DocumentsBloc()
          ..add(LoadDocumentsRequested(
              sessionToken: (SessionStore.current?.token ?? "").trim())),
        child: const _DocumentUploadView(),
      );
    }
  }
}

enum _DocFilter { all, pendingUpload, inReview, rejected, approved }

class _DocumentUploadView extends StatefulWidget {
  const _DocumentUploadView();

  @override
  State<_DocumentUploadView> createState() => _DocumentUploadViewState();
}

class _DocumentUploadViewState extends State<_DocumentUploadView> {
  _DocFilter _selectedFilter = _DocFilter.all;

  String get _token => (SessionStore.current?.token ?? "").trim();

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _addCustomDocument(
      BuildContext context, DocumentsState state) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add More Document"),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Document Name",
            ),
            onSubmitted: (_) =>
                Navigator.of(dialogContext).pop(ctrl.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ctrl.text.trim()),
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );

    if (name == null) return;

    final trimmed = name.trim();
    final customError = _validateCustomDocumentName(trimmed);
    if (customError != null) {
      if (!context.mounted) return;
      _showSnackBar(context, customError, isError: true);
      return;
    }

    if (!context.mounted) return;
    await _handleUpload(
      context: context,
      definition: _customDefinition,
      customDocumentName: trimmed,
      busyKey: "custom::$trimmed",
      state: state,
    );
  }

  Future<void> _handleUpload({
    required BuildContext context,
    required _DocumentDefinition definition,
    required String busyKey,
    required DocumentsState state,
    String? customDocumentName,
  }) async {
    if (state.busyKeys.contains(busyKey)) return;

    if (definition.type != "other") {
      EngineerDocument? existingDoc;
      for (final d in state.documents) {
        if (d.documentType == definition.type) {
          existingDoc = d;
          break;
        }
      }
      if (existingDoc != null &&
          existingDoc.verificationStatus.trim().toUpperCase() == "APPROVED") {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Replace Approved Document?"),
            content: Text(
              "Your ${definition.displayName} is already approved. Uploading a new file will replace the current document and submit it for Admin review.\n\nDo you want to continue?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Replace & Upload"),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
    }

    DateTime? ndtExpiryDate;
    if (definition.type == "ndt") {
      ndtExpiryDate = await _pickNdtExpiryDate(context, state.ndtExpiryDate);
      if (ndtExpiryDate == null) return;
    }

    if (!context.mounted) return;
    final selected = await _pickFile(context, definition);
    if (selected == null) return;

    final validationError = _validateSelectedFile(
        definition: definition,
        selected: selected,
        customDocumentName: customDocumentName);
    if (validationError != null) {
      if (!context.mounted) return;
      _showSnackBar(context, validationError, isError: true);
      return;
    }

    final token = _token;
    if (token.isEmpty) {
      if (!context.mounted) return;
      _showSnackBar(context, "Session expired. Please login again.",
          isError: true);
      return;
    }

    if (!context.mounted) return;
    context.read<DocumentsBloc>().add(UploadDocumentRequested(
          sessionToken: token,
          documentType: definition.type,
          documentName: customDocumentName ?? definition.displayName,
          bytes: selected.bytes,
          originalFileName: selected.fileName,
          contentType: selected.contentType,
          sizeBytes: selected.sizeBytes,
          fileExtension: selected.fileExtension,
          ndtExpiryDate: ndtExpiryDate,
          busyKey: busyKey,
        ));
  }

  Future<_SelectedUploadFile?> _pickFile(
      BuildContext context, _DocumentDefinition definition) async {
    if (definition.allowsCameraOrGallery) {
      final source = await showModalBottomSheet<_DocumentPickSource>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text("Camera"),
                onTap: () =>
                    Navigator.of(context).pop(_DocumentPickSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Gallery"),
                onTap: () =>
                    Navigator.of(context).pop(_DocumentPickSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: const Text("Files"),
                onTap: () =>
                    Navigator.of(context).pop(_DocumentPickSource.files),
              ),
            ],
          ),
        ),
      );

      if (source == null) return null;
      if (!context.mounted) return null;
      switch (source) {
        case _DocumentPickSource.camera:
          return _pickWithImagePicker(context, ImageSource.camera);
        case _DocumentPickSource.gallery:
          return _pickWithImagePicker(context, ImageSource.gallery);
        case _DocumentPickSource.files:
          return _pickWithFilePicker(context,
              allowedExtensions: _pickerExtensionsForDefinition(definition));
      }
    }

    return _pickWithFilePicker(context,
        allowedExtensions: _pickerExtensionsForDefinition(definition));
  }

  Future<_SelectedUploadFile?> _pickWithFilePicker(BuildContext context,
      {required List<String> allowedExtensions}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw "Unable to read the selected file";
      }

      final name = file.name.trim();
      final prepared = _prepareSelectedFile(
        fileName: name,
        bytes: bytes,
        explicitSize: file.size,
      );
      return prepared;
    } catch (e) {
      if (context.mounted) {
        final appError = ErrorHandler.handle(e);
        _showSnackBar(context, appError.userMessage, isError: true);
      }
      return null;
    }
  }

  Future<_SelectedUploadFile?> _pickWithImagePicker(
      BuildContext context, ImageSource source) async {
    try {
      final imagePicker = ImagePicker();
      final file = await imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final name = file.name.trim().isEmpty
          ? file.path.split(Platform.pathSeparator).last
          : file.name.trim();
      return _prepareSelectedFile(
        fileName: name,
        bytes: bytes,
        explicitSize: bytes.length,
      );
    } catch (e) {
      if (context.mounted) {
        final appError = ErrorHandler.handle(e);
        _showSnackBar(context, appError.userMessage, isError: true);
      }
      return null;
    }
  }

  _SelectedUploadFile _prepareSelectedFile({
    required String fileName,
    required Uint8List bytes,
    required int explicitSize,
  }) {
    final extension = _extensionOf(fileName);
    final contentType = _contentTypeForExtension(extension);
    if (contentType == null) {
      throw "Unsupported format. Please select a valid file type.";
    }

    final size = explicitSize > 0 ? explicitSize : bytes.length;
    if (size > DocumentsService.maxBytes) {
      throw "File size too large. Please upload a file smaller than 15 MB.";
    }

    return _SelectedUploadFile(
      fileName: fileName,
      bytes: bytes,
      sizeBytes: size,
      fileExtension: extension,
      contentType: contentType,
    );
  }

  Future<DateTime?> _pickNdtExpiryDate(
      BuildContext context, DateTime? currentStateNdtDate) async {
    final today = DateTime.now();
    final initial =
        currentStateNdtDate ?? DateTime(today.year + 1, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: DateTime(today.year - 1, 1, 1),
      lastDate: DateTime(today.year + 20, 12, 31),
      helpText: "Select NDT Expiry Date",
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day);
  }

  String? _validateCustomDocumentName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "Document name is required";
    if (trimmed.length < 3) {
      return "Document name must be at least 3 characters";
    }
    if (!RegExp(r"^[A-Za-z0-9 &()_\-./]+$").hasMatch(trimmed)) {
      return "Document name contains invalid characters";
    }
    return null;
  }

  String? _validateSelectedFile({
    required _DocumentDefinition definition,
    required _SelectedUploadFile selected,
    String? customDocumentName,
  }) {
    if (definition.type == "other") {
      final customError = _validateCustomDocumentName(customDocumentName ?? "");
      if (customError != null) return customError;
    }

    final ext = selected.fileExtension.trim().toLowerCase();
    final allowed = definition.allowedExtensions;
    if (allowed.isNotEmpty && !allowed.contains(ext)) {
      return "Invalid file type for ${definition.displayName}. Allowed: ${allowed.join(", ").toUpperCase()}";
    }
    return null;
  }

  List<String> _pickerExtensionsForDefinition(_DocumentDefinition definition) {
    if (definition.allowedExtensions.isNotEmpty) {
      return definition.allowedExtensions;
    }
    return definition.allowPdf
        ? const ["pdf", "jpg", "jpeg", "png"]
        : const ["jpg", "jpeg", "png"];
  }

  String? _ndtReminderText(DateTime? expiry) {
    if (expiry == null) return null;
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final diffDays = expiry.difference(startToday).inDays;
    final label = _formatDate(expiry);
    if (diffDays < 0) {
      return "Expired on $label";
    }
    if (diffDays <= 30) {
      return "Reminder: expires in $diffDays day${diffDays == 1 ? "" : "s"} on $label";
    }
    return "Expiry date: $label";
  }

  Color? _ndtReminderColor(BuildContext context, DateTime? expiry) {
    if (expiry == null) return null;
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final diffDays = expiry.difference(startToday).inDays;
    if (diffDays < 0) return Theme.of(context).colorScheme.error;
    if (diffDays <= 30) {
      return Theme.of(context).extension<AppColorsExtension>()!.warning;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, "0");
    final m = date.month.toString().padLeft(2, "0");
    final y = date.year.toString().padLeft(4, "0");
    return "$d-$m-$y";
  }

  Future<void> _viewDocument(BuildContext context, EngineerDocument document,
      DocumentsState state) async {
    final busyKey = "view::${document.id}";
    if (state.busyKeys.contains(busyKey)) return;

    final url = document.fileUrl.trim();
    if (url.isEmpty) {
      _showSnackBar(context, "No file is available to view", isError: true);
      return;
    }

    context
        .read<DocumentsBloc>()
        .add(ViewDocumentRequested(document: document, busyKey: busyKey));
  }

  Future<void> _downloadDocument(BuildContext context, EngineerDocument document,
      DocumentsState state) async {
    final busyKey = "download::${document.id}";
    if (state.busyKeys.contains(busyKey)) return;

    final url = document.fileUrl.trim();
    if (url.isEmpty) {
      _showSnackBar(context, "No file is available to download", isError: true);
      return;
    }

    context.read<DocumentsBloc>().add(
        DownloadDocumentToPhoneRequested(document: document, busyKey: busyKey));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<DocumentsBloc, DocumentsState>(
      listenWhen: (previous, current) =>
          current.snackbarMessage != previous.snackbarMessage ||
          current.downloadedFilePath != previous.downloadedFilePath,
      listener: (context, state) {
        if (state.snackbarMessage != null) {
          _showSnackBar(context, state.snackbarMessage!,
              isError: state.isErrorSnackbar);
        }
        if (state.downloadedFilePath != null) {
          if (state.isImageDownloaded) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageViewer(url: state.downloadedFilePath!),
              ),
            );
          } else {
            OpenFilex.open(state.downloadedFilePath!);
          }
        }
      },
      builder: (context, state) {
        final isLoading = state.status == DocumentsStatus.loading ||
            state.status == DocumentsStatus.initial;

        // Group documents
        final latestByType = <String, EngineerDocument>{};
        final customDocuments = <EngineerDocument>[];
        for (final doc in state.documents) {
          if (doc.documentType == "other") {
            customDocuments.add(doc);
          } else {
            latestByType.putIfAbsent(doc.documentType, () => doc);
          }
        }
        customDocuments.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        final department = SessionStore.current?.engineer.department;
        final definitions = _getDefinitionsForDepartment(department);
        final requiredDefinitions = definitions.where((d) => d.isRequired).toList();
        final optionalDefinitions = definitions.where((d) => !d.isRequired).toList();

        final totalRequired = requiredDefinitions.length;
        int validUploadedRequired = 0;
        int approvedCount = 0;
        int pendingReviewCount = 0;
        int rejectedCount = 0;
        int pendingUploadRequired = 0;

        for (final def in requiredDefinitions) {
          final doc = latestByType[def.type];
          if (doc == null || doc.fileUrl.trim().isEmpty) {
            pendingUploadRequired++;
          }
        }

        for (final def in definitions) {
          final doc = latestByType[def.type];
          if (doc != null && doc.fileUrl.trim().isNotEmpty) {
            final status = doc.verificationStatus.trim().toUpperCase();
            if (status == "APPROVED") {
              approvedCount++;
              if (def.isRequired) validUploadedRequired++;
            } else if (status == "REJECTED") {
              rejectedCount++;
            } else {
              pendingReviewCount++;
              if (def.isRequired) validUploadedRequired++;
            }
          }
        }

        for (final doc in customDocuments) {
          if (doc.fileUrl.trim().isNotEmpty) {
            final status = doc.verificationStatus.trim().toUpperCase();
            if (status == "APPROVED") {
              approvedCount++;
            } else if (status == "REJECTED") {
              rejectedCount++;
            } else {
              pendingReviewCount++;
            }
          }
        }

        final progress = totalRequired > 0 ? (validUploadedRequired / totalRequired).clamp(0.0, 1.0) : 0.0;

        final visibleRequired = requiredDefinitions
            .where((d) => _matchesFilter(_selectedFilter, latestByType[d.type]))
            .toList();
        final visibleOptional = _selectedFilter == _DocFilter.pendingUpload
            ? const <_DocumentDefinition>[]
            : optionalDefinitions
                .where((d) => _matchesFilter(_selectedFilter, latestByType[d.type]))
                .toList();
        final visibleCustom = _selectedFilter == _DocFilter.pendingUpload
            ? const <EngineerDocument>[]
            : customDocuments
                .where((doc) => _matchesFilter(_selectedFilter, doc))
                .toList();
        final totalAllDocs = definitions.length + customDocuments.length;
        final hasAnyVisible = visibleRequired.isNotEmpty ||
            visibleOptional.isNotEmpty ||
            visibleCustom.isNotEmpty;

        return Scaffold(
          backgroundColor: cs.surface,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<DocumentsBloc>().add(
                    LoadDocumentsRequested(
                        sessionToken: _token, showLoader: true));
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: CustomScrollView(
                slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: cs.surface,
                  scrolledUnderElevation: 1,
                  title: Row(
                    children: [
                      Icon(Icons.folder_shared_rounded, color: cs.primary),
                      const SizedBox(width: 12),
                      Text(
                        "My Documents",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  actions: const [],
                ),
                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildComplianceSummaryCard(
                            context: context,
                            streamName: department,
                            totalRequired: totalRequired,
                            uploadedRequired: validUploadedRequired,
                            progress: progress,
                            requiredDefinitions: requiredDefinitions,
                            latestByType: latestByType,
                          ),
                          if (rejectedCount > 0) ...[
                            const SizedBox(height: 12),
                            _buildRejectionAlertBanner(context, rejectedCount),
                          ],
                          const SizedBox(height: 12),
                          _InfoCard(
                              loadError: state.status == DocumentsStatus.error
                                  ? state.errorMessage
                                  : null),
                          const SizedBox(height: 20),
                          _buildFilterTabs(
                            context: context,
                            totalAllDocs: totalAllDocs,
                            pendingUploadCount: pendingUploadRequired,
                            inReviewCount: pendingReviewCount,
                            rejectedCount: rejectedCount,
                            approvedCount: approvedCount,
                          ),
                          const SizedBox(height: 20),

                          if (_selectedFilter != _DocFilter.all && !hasAnyVisible)
                            _buildFilterEmptyCard(context, _selectedFilter)
                          else ...[
                            if (visibleRequired.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      "Required Documents",
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "$validUploadedRequired/$totalRequired",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...visibleRequired.map((definition) {
                                final doc = latestByType[definition.type];
                                final busyKey = "upload::${definition.type}";
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _DocumentCard(
                                    title: definition.displayName,
                                    requiredLabel: _requiredLabel(definition, doc),
                                    requiredColor: _requiredColor(context, definition, doc),
                                    statusLabel: _statusLabel(doc),
                                    statusColor: _statusColor(context, doc),
                                    remarks: doc?.adminRemarks,
                                    helperText: definition.type == "ndt"
                                        ? _ndtReminderText(state.ndtExpiryDate)
                                        : null,
                                    helperColor: definition.type == "ndt"
                                        ? _ndtReminderColor(context, state.ndtExpiryDate)
                                        : null,
                                    isUploading: state.busyKeys.contains(busyKey),
                                    isViewing: doc != null &&
                                        state.busyKeys.contains("view::${doc.id}"),
                                    onUpload: () => _handleUpload(
                                        context: context,
                                        definition: definition,
                                        busyKey: busyKey,
                                        state: state),
                                    onView: doc != null && doc.fileUrl.trim().isNotEmpty
                                        ? () => _viewDocument(context, doc, state)
                                        : null,
                                    onDownload: doc != null && doc.fileUrl.trim().isNotEmpty
                                        ? () => _downloadDocument(context, doc, state)
                                        : null,
                                    isDownloading: doc != null &&
                                        state.busyKeys.contains("download::${doc.id}"),
                                    uploadLabel: doc == null ? "Upload" : "Re-upload",
                                  ),
                                );
                              }),
                            ],

                            if (visibleOptional.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 12),
                                child: Text(
                                  "Optional Documents",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                ),
                              ),
                              ...visibleOptional.map((definition) {
                                final doc = latestByType[definition.type];
                                final busyKey = "upload::${definition.type}";
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _DocumentCard(
                                    title: definition.displayName,
                                    requiredLabel: _requiredLabel(definition, doc),
                                    requiredColor: _requiredColor(context, definition, doc),
                                    statusLabel: _statusLabel(doc),
                                    statusColor: _statusColor(context, doc),
                                    remarks: doc?.adminRemarks,
                                    helperText: definition.type == "ndt"
                                        ? _ndtReminderText(state.ndtExpiryDate)
                                        : null,
                                    helperColor: definition.type == "ndt"
                                        ? _ndtReminderColor(context, state.ndtExpiryDate)
                                        : null,
                                    isUploading: state.busyKeys.contains(busyKey),
                                    isViewing: doc != null &&
                                        state.busyKeys.contains("view::${doc.id}"),
                                    onUpload: () => _handleUpload(
                                        context: context,
                                        definition: definition,
                                        busyKey: busyKey,
                                        state: state),
                                    onView: doc != null && doc.fileUrl.trim().isNotEmpty
                                        ? () => _viewDocument(context, doc, state)
                                        : null,
                                    onDownload: doc != null && doc.fileUrl.trim().isNotEmpty
                                        ? () => _downloadDocument(context, doc, state)
                                        : null,
                                    isDownloading: doc != null &&
                                        state.busyKeys.contains("download::${doc.id}"),
                                    uploadLabel: doc == null ? "Upload" : "Re-upload",
                                  ),
                                );
                              }),
                            ],

                            if (_selectedFilter == _DocFilter.all || visibleCustom.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        "Custom Documents",
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: cs.primary,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _addCustomDocument(context, state),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text("Add New"),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (customDocuments.isEmpty && _selectedFilter == _DocFilter.all)
                                const _EmptyCustomCard()
                              else
                                ...visibleCustom.map((doc) {
                                  final busyKey = "custom::${doc.documentName}";
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _DocumentCard(
                                      title: doc.documentName,
                                      requiredLabel: _requiredLabel(_customDefinition, doc),
                                      requiredColor: _requiredColor(context, _customDefinition, doc),
                                      statusLabel: _statusLabel(doc),
                                      statusColor: _statusColor(context, doc),
                                      remarks: doc.adminRemarks,
                                      helperText: null,
                                      helperColor: null,
                                      isUploading: state.busyKeys.contains(busyKey),
                                      isViewing: state.busyKeys.contains("view::${doc.id}"),
                                      isDownloading: state.busyKeys.contains("download::${doc.id}"),
                                      onUpload: () => _handleUpload(
                                        context: context,
                                        definition: _customDefinition,
                                        customDocumentName: doc.documentName,
                                        busyKey: busyKey,
                                        state: state,
                                      ),
                                      onView: doc.fileUrl.trim().isNotEmpty
                                          ? () => _viewDocument(context, doc, state)
                                          : null,
                                      onDownload: doc.fileUrl.trim().isNotEmpty
                                          ? () => _downloadDocument(context, doc, state)
                                          : null,
                                      uploadLabel: "Re-upload",
                                    ),
                                  );
                                }),
                            ],
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          )
        );
      },
    );
  }

  String _requiredLabel(_DocumentDefinition definition, EngineerDocument? doc) {
    final backend = (doc?.requiredLabel ?? "").trim();
    if (backend.isNotEmpty) return backend;
    return definition.isRequired ? "Required" : "Optional";
  }

  Color _requiredColor(BuildContext context, _DocumentDefinition definition,
      EngineerDocument? doc) {
    return definition.isRequired
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _statusLabel(EngineerDocument? doc) {
    if (doc == null) return "Not uploaded";
    switch (doc.verificationStatus.trim().toUpperCase()) {
      case "APPROVED":
        return "Approved";
      case "REJECTED":
        return "Rejected — upload replacement";
      case "PENDING":
      default:
        return "Awaiting approval";
    }
  }

  Color _statusColor(BuildContext context, EngineerDocument? doc) {
    if (doc == null) return Theme.of(context).colorScheme.onSurfaceVariant;
    switch (doc.verificationStatus.trim().toUpperCase()) {
      case "APPROVED":
        return Theme.of(context).extension<AppColorsExtension>()!.success;
      case "REJECTED":
        return Theme.of(context).colorScheme.error;
      case "PENDING":
      default:
        return Theme.of(context).extension<AppColorsExtension>()!.warning;
    }
  }

  Widget _buildComplianceSummaryCard({
    required BuildContext context,
    String? streamName,
    required int totalRequired,
    required int uploadedRequired,
    required double progress,
    required List<_DocumentDefinition> requiredDefinitions,
    required Map<String, EngineerDocument> latestByType,
  }) {
    final cs = Theme.of(context).colorScheme;
    final percent = (progress * 100).toInt();

    // Build exact Admin outstandingRequiredDocuments list:
    // Any required document whose status is NOT "APPROVED" is still remaining.
    final outstandingRequired = <MapEntry<String, String>>[];
    for (final req in requiredDefinitions) {
      final doc = latestByType[req.type];
      final statusUpper = doc?.verificationStatus.trim().toUpperCase() ?? "";
      if (statusUpper == "APPROVED") continue;
      final statusText = statusUpper == "PENDING"
          ? "Awaiting approval"
          : statusUpper == "REJECTED"
              ? "Rejected — upload a replacement"
              : "Not uploaded";
      outstandingRequired.add(MapEntry(req.displayName, statusText));
    }

    final isAllApproved = totalRequired > 0 && outstandingRequired.isEmpty;

    String subtitle;
    if (totalRequired == 0) {
      subtitle =
          "Required-document tracking is not configured for this department.";
    } else if (isAllApproved) {
      subtitle = "All required documents are approved.";
    } else {
      final rem = outstandingRequired.length;
      subtitle =
          "$rem required document${rem == 1 ? "" : "s"} remaining ($uploadedRequired/$totalRequired uploaded)";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAllApproved
              ? [
                  const Color(0xFF10B981).withValues(alpha: 0.12),
                  const Color(0xFF059669).withValues(alpha: 0.05),
                ]
              : [
                  cs.primaryContainer.withValues(alpha: 0.45),
                  cs.surfaceContainerHighest.withValues(alpha: 0.35),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAllApproved
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAllApproved
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAllApproved
                      ? Icons.verified_user_rounded
                      : Icons.folder_shared_rounded,
                  color: isAllApproved ? const Color(0xFF10B981) : cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Upload & Verification Status",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (streamName != null && streamName.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Stream: ${streamName.trim()}",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (totalRequired > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAllApproved
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$percent%",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isAllApproved ? const Color(0xFF10B981) : cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (totalRequired > 0 && outstandingRequired.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${outstandingRequired.length} required document${outstandingRequired.length == 1 ? '' : 's'} remaining",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                  ),
                  const SizedBox(height: 6),
                  ...outstandingRequired.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              "${entry.key}: ${entry.value}",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: entry.value.startsWith("Rejected")
                                        ? cs.error
                                        : entry.value == "Awaiting approval"
                                            ? Colors.amber.shade900
                                            : cs.onSurfaceVariant,
                                    fontWeight: entry.value.startsWith("Rejected")
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (totalRequired > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isAllApproved ? const Color(0xFF10B981) : cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectionAlertBanner(BuildContext context, int rejectedCount) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFEF4444),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Action Required: $rejectedCount Document${rejectedCount == 1 ? '' : 's'} Rejected",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Please review admin remarks on the rejected document${rejectedCount == 1 ? '' : 's'} and re-upload.",
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs({
    required BuildContext context,
    required int totalAllDocs,
    required int pendingUploadCount,
    required int inReviewCount,
    required int rejectedCount,
    required int approvedCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            context: context,
            label: "All",
            filter: _DocFilter.all,
            count: totalAllDocs,
          ),
          _buildFilterChip(
            context: context,
            label: "Pending Upload",
            filter: _DocFilter.pendingUpload,
            count: pendingUploadCount,
          ),
          _buildFilterChip(
            context: context,
            label: "In Review",
            filter: _DocFilter.inReview,
            count: inReviewCount,
          ),
          _buildFilterChip(
            context: context,
            label: "Rejected",
            filter: _DocFilter.rejected,
            count: rejectedCount,
          ),
          _buildFilterChip(
            context: context,
            label: "Approved",
            filter: _DocFilter.approved,
            count: approvedCount,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required _DocFilter filter,
    required int count,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedFilter == filter;

    Color badgeColor;
    switch (filter) {
      case _DocFilter.approved:
        badgeColor = const Color(0xFF10B981);
        break;
      case _DocFilter.inReview:
        badgeColor = const Color(0xFFF59E0B);
        break;
      case _DocFilter.pendingUpload:
        badgeColor = const Color(0xFF3B82F6);
        break;
      case _DocFilter.rejected:
        badgeColor = const Color(0xFFEF4444);
        break;
      case _DocFilter.all:
        badgeColor = cs.primary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        selectedColor: badgeColor.withValues(alpha: 0.18),
        side: BorderSide(
          color: isSelected
              ? badgeColor
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1.0,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? badgeColor : cs.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? badgeColor.withValues(alpha: 0.25)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? badgeColor : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        onSelected: (_) {
          setState(() {
            _selectedFilter = isSelected ? _DocFilter.all : filter;
          });
        },
      ),
    );
  }

  bool _matchesFilter(_DocFilter filter, EngineerDocument? doc) {
    switch (filter) {
      case _DocFilter.all:
        return true;
      case _DocFilter.pendingUpload:
        return doc == null || doc.fileUrl.trim().isEmpty;
      case _DocFilter.inReview:
        return doc != null &&
            doc.fileUrl.trim().isNotEmpty &&
            doc.verificationStatus.trim().toUpperCase() == "PENDING";
      case _DocFilter.rejected:
        return doc != null &&
            doc.fileUrl.trim().isNotEmpty &&
            doc.verificationStatus.trim().toUpperCase() == "REJECTED";
      case _DocFilter.approved:
        return doc != null &&
            doc.fileUrl.trim().isNotEmpty &&
            doc.verificationStatus.trim().toUpperCase() == "APPROVED";
    }
  }

  Widget _buildFilterEmptyCard(BuildContext context, _DocFilter filter) {
    String title;
    String message;
    IconData icon;
    Color iconColor;

    switch (filter) {
      case _DocFilter.pendingUpload:
        title = "No Pending Uploads";
        message = "All required documents have already been uploaded.";
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case _DocFilter.inReview:
        title = "No Documents In Review";
        message = "You don't have any documents currently awaiting admin review.";
        icon = Icons.schedule_rounded;
        iconColor = const Color(0xFFF59E0B);
        break;
      case _DocFilter.rejected:
        title = "No Rejected Documents";
        message = "None of your documents have been rejected. Everything looks good!";
        icon = Icons.verified_user_outlined;
        iconColor = const Color(0xFF10B981);
        break;
      case _DocFilter.approved:
        title = "No Approved Documents Yet";
        message = "Documents uploaded will appear here once verified by admin.";
        icon = Icons.folder_outlined;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case _DocFilter.all:
        title = "No Documents";
        message = "No documents found.";
        icon = Icons.folder_outlined;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedFilter = _DocFilter.all;
              });
            },
            child: const Text("Show All Documents"),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatefulWidget {
  const _DocumentCard({
    required this.title,
    required this.requiredLabel,
    required this.requiredColor,
    required this.statusLabel,
    required this.statusColor,
    required this.remarks,
    required this.helperText,
    required this.helperColor,
    required this.isUploading,
    required this.isViewing,
    this.isDownloading = false,
    required this.onUpload,
    required this.onView,
    this.onDownload,
    required this.uploadLabel,
  });

  final String title;
  final String requiredLabel;
  final Color requiredColor;
  final String statusLabel;
  final Color statusColor;
  final String? remarks;
  final String? helperText;
  final Color? helperColor;
  final bool isUploading;
  final bool isViewing;
  final bool isDownloading;
  final VoidCallback onUpload;
  final VoidCallback? onView;
  final VoidCallback? onDownload;
  final String uploadLabel;

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayRemarks = (widget.remarks ?? "").trim();
    final displayHelper = (widget.helperText ?? "").trim();
    
    final isApproved = widget.statusLabel.toLowerCase() == "approved";
    final isRejected = widget.statusLabel.toLowerCase() == "rejected";

    final cardBackgroundColor = isApproved
        ? const Color(0xFF10B981).withValues(alpha: 0.08)
        : (isRejected
            ? cs.errorContainer.withValues(alpha: 0.15)
            : cs.surface);

    final cardBorderColor = isApproved
        ? const Color(0xFF10B981).withValues(alpha: 0.3)
        : (isRejected
            ? cs.error.withValues(alpha: 0.3)
            : cs.outlineVariant.withValues(alpha: 0.6));

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusChip(
                          label: widget.statusLabel,
                          color: widget.statusColor,
                          textColor: Colors.white),
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            if (displayHelper.isNotEmpty || displayRemarks.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isApproved
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayHelper.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: widget.helperColor ?? cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayHelper,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: widget.helperColor ?? cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    if (displayHelper.isNotEmpty && displayRemarks.isNotEmpty)
                      const SizedBox(height: 8),
                    if (displayRemarks.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isApproved
                                ? Icons.verified_user_outlined
                                : Icons.feedback_rounded,
                            size: 16,
                            color: isApproved
                                ? const Color(0xFF10B981)
                                : cs.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Remarks: $displayRemarks",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isApproved
                                        ? const Color(0xFF10B981)
                                        : cs.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                border: Border(
                  top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                children: [
                  if (widget.onView != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.isViewing ? null : widget.onView,
                        icon: widget.isViewing
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: cs.primary),
                              )
                            : const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text("View", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                      ),
                    ),
                    if (widget.onDownload != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.isDownloading ? null : widget.onDownload,
                          icon: widget.isDownloading
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.primary),
                                )
                              : const Icon(Icons.download_rounded, size: 16),
                          label: const Text("Save", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.isUploading ? null : widget.onUpload,
                      icon: widget.isUploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              widget.statusLabel.toLowerCase() != "not uploaded"
                                  ? Icons.refresh_rounded
                                  : Icons.upload_file_rounded,
                              size: 16),
                      label: Text(widget.uploadLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.loadError});

  final String? loadError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CV supports PDF, DOC, and DOCX. Other documents support PDF or image files. Max size is 15 MB.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "NDT upload requires an expiry date. Selfie & signature support camera, gallery, or files.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  if ((loadError ?? "").trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "API warning: $loadError",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCustomCard extends StatelessWidget {
  const _EmptyCustomCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_open_rounded, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              "No custom documents",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Use 'Add New' to upload an extra file.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedUploadFile {
  const _SelectedUploadFile({
    required this.fileName,
    required this.bytes,
    required this.sizeBytes,
    required this.fileExtension,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final int sizeBytes;
  final String fileExtension;
  final String contentType;
}

enum _DocumentPickSource { camera, gallery, files }

class _DocumentDefinition {
  const _DocumentDefinition({
    required this.type,
    required this.displayName,
    required this.isRequired,
    this.allowPdf = true,
    this.allowsCameraOrGallery = false,
    this.allowedExtensions = const <String>[],
  });

  final String type;
  final String displayName;
  final bool isRequired;
  final bool allowPdf;
  final bool allowsCameraOrGallery;
  final List<String> allowedExtensions;

  _DocumentDefinition copyWith({
    String? type,
    String? displayName,
    bool? isRequired,
    bool? allowPdf,
    bool? allowsCameraOrGallery,
    List<String>? allowedExtensions,
  }) {
    return _DocumentDefinition(
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      isRequired: isRequired ?? this.isRequired,
      allowPdf: allowPdf ?? this.allowPdf,
      allowsCameraOrGallery:
          allowsCameraOrGallery ?? this.allowsCameraOrGallery,
      allowedExtensions: allowedExtensions ?? this.allowedExtensions,
    );
  }
}

const Set<String> _kMechanicalRequiredTypes = {
  "cv",
  "degree",
  "ndt",
  "pan",
  "aadhaar",
  "bank_passbook",
};

const Set<String> _kElectricalCivilRequiredTypes = {
  "cv",
  "degree",
  "pan",
  "aadhaar",
  "bank_passbook",
};

Set<String> _getRequiredTypesForDepartment(String? department) {
  final norm = (department ?? "").trim().toLowerCase();
  if (norm.contains("mech")) {
    return _kMechanicalRequiredTypes;
  }
  return _kElectricalCivilRequiredTypes;
}

const List<_DocumentDefinition> _allStandardDefinitions = <_DocumentDefinition>[
  _DocumentDefinition(
    type: "cv",
    displayName: "CV / Resume",
    isRequired: true,
    allowedExtensions: <String>["pdf", "doc", "docx"],
  ),
  _DocumentDefinition(
    type: "degree",
    displayName: "Degree / Diploma Certificate",
    isRequired: true,
  ),
  _DocumentDefinition(
    type: "ndt",
    displayName: "NDT Certificate",
    isRequired: true,
  ),
  _DocumentDefinition(
    type: "pan",
    displayName: "PAN Card",
    isRequired: true,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(
    type: "aadhaar",
    displayName: "Aadhaar Card",
    isRequired: true,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(
    type: "bank_passbook",
    displayName: "Bank Passbook / Cancelled Cheque",
    isRequired: true,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(
    type: "selfie",
    displayName: "Selfie / Passport Size Photo",
    isRequired: false,
    allowPdf: false,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(
    type: "signature",
    displayName: "Signature Photo",
    isRequired: false,
    allowPdf: false,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(
    type: "appointment_letter",
    displayName: "Signed Appointment Letter",
    isRequired: false,
  ),
];

List<_DocumentDefinition> _getDefinitionsForDepartment(String? department) {
  final requiredTypes = _getRequiredTypesForDepartment(department);
  return _allStandardDefinitions.map((def) {
    return def.copyWith(isRequired: requiredTypes.contains(def.type));
  }).toList();
}

const _DocumentDefinition _customDefinition = _DocumentDefinition(
  type: "other",
  displayName: "Custom Document",
  isRequired: false,
);

String _extensionOf(String fileName) {
  final normalized = fileName.trim().toLowerCase();
  final dot = normalized.lastIndexOf(".");
  if (dot == -1 || dot == normalized.length - 1) return "";
  return normalized.substring(dot + 1);
}

String? _contentTypeForExtension(String extension) {
  switch (extension.trim().toLowerCase()) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "png":
      return "image/png";
    case "pdf":
      return "application/pdf";
    case "doc":
      return "application/msword";
    case "docx":
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    default:
      return null;
  }
}
