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
import "package:sitepulse_engineer/shared/widgets/section_header.dart";
import "package:sitepulse_engineer/shared/widgets/status_chip.dart";
import "package:sitepulse_engineer/features/documents/presentation/bloc/documents_bloc.dart";

import "../../../../core/theme/app_colors_extension.dart";

class DocumentUploadScreen extends StatelessWidget {
  const DocumentUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DocumentsBloc()
        ..add(LoadDocumentsRequested(
            sessionToken: (SessionStore.current?.token ?? "").trim())),
      child: const _DocumentUploadView(),
    );
  }
}

class _DocumentUploadView extends StatelessWidget {
  const _DocumentUploadView();

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
              hintText: "Enter custom document name",
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
        _showSnackBar(context, e.toString(), isError: true);
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
        _showSnackBar(context, e.toString(), isError: true);
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

    if (_isImageDocument(document)) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ImageViewer(url: url)));
      return;
    }

    context
        .read<DocumentsBloc>()
        .add(ViewDocumentRequested(document: document, busyKey: busyKey));
  }

  bool _isImageDocument(EngineerDocument doc) {
    final ct = doc.contentType.trim().toLowerCase();
    if (ct.startsWith("image/")) return true;
    final ext = doc.effectiveFileName.split('.').last.toLowerCase();
    return ext == "jpg" || ext == "jpeg" || ext == "png";
  }

  @override
  Widget build(BuildContext context) {
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
          OpenFilex.open(state.downloadedFilePath!);
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
            latestByType[doc.documentType] = doc;
          }
        }
        customDocuments.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        return Scaffold(
          appBar: AppBar(
            title: const Text("Documents"),
            actions: [
              IconButton(
                onPressed: isLoading
                    ? null
                    : () => context.read<DocumentsBloc>().add(
                        LoadDocumentsRequested(
                            sessionToken: _token, showLoader: true)),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(18),
                    child: ListView(
                      children: [
                        _InfoCard(
                            loadError: state.status == DocumentsStatus.error
                                ? state.errorMessage
                                : null),
                        const SizedBox(height: 18),
                        const SectionHeader(title: "Required Documents"),
                        const SizedBox(height: 12),
                        ..._defaultDefinitions.map((definition) {
                          final doc = latestByType[definition.type];
                          final busyKey = "upload::${definition.type}";
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _DocumentCard(
                              title: definition.displayName,
                              requiredLabel: _requiredLabel(definition, doc),
                              requiredColor:
                                  _requiredColor(context, definition, doc),
                              statusLabel: _statusLabel(doc),
                              statusColor: _statusColor(context, doc),
                              remarks: doc?.adminRemarks,
                              helperText: definition.type == "ndt"
                                  ? _ndtReminderText(state.ndtExpiryDate)
                                  : null,
                              helperColor: definition.type == "ndt"
                                  ? _ndtReminderColor(
                                      context, state.ndtExpiryDate)
                                  : null,
                              isUploading: state.busyKeys.contains(busyKey),
                              isViewing: doc != null &&
                                  state.busyKeys.contains("view::${doc.id}"),
                              onUpload: () => _handleUpload(
                                  context: context,
                                  definition: definition,
                                  busyKey: busyKey,
                                  state: state),
                              onView:
                                  doc != null && doc.fileUrl.trim().isNotEmpty
                                      ? () => _viewDocument(context, doc, state)
                                      : null,
                              uploadLabel: doc == null ? "Upload" : "Re-upload",
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        SectionHeader(
                          title: "Custom Documents",
                          trailing: OutlinedButton.icon(
                            onPressed: () => _addCustomDocument(context, state),
                            icon: const Icon(Icons.add),
                            label: const Text("Add More Document"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (customDocuments.isEmpty)
                          const _EmptyCustomCard()
                        else
                          ...customDocuments.map((doc) {
                            final busyKey = "custom::${doc.documentName}";
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _DocumentCard(
                                title: doc.documentName,
                                requiredLabel:
                                    _requiredLabel(_customDefinition, doc),
                                requiredColor: _requiredColor(
                                    context, _customDefinition, doc),
                                statusLabel: _statusLabel(doc),
                                statusColor: _statusColor(context, doc),
                                remarks: doc.adminRemarks,
                                helperText: null,
                                helperColor: null,
                                isUploading: state.busyKeys.contains(busyKey),
                                isViewing:
                                    state.busyKeys.contains("view::${doc.id}"),
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
                                uploadLabel: "Re-upload",
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _requiredLabel(_DocumentDefinition definition, EngineerDocument? doc) {
    final backend = (doc?.requiredLabel ?? "").trim();
    if (backend.isNotEmpty) return backend;
    final isRequired = doc?.isRequired ?? definition.isRequired;
    return isRequired ? "Required" : "Optional";
  }

  Color _requiredColor(BuildContext context, _DocumentDefinition definition,
      EngineerDocument? doc) {
    final isRequired = doc?.isRequired ?? definition.isRequired;
    return isRequired
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _statusLabel(EngineerDocument? doc) {
    if (doc == null) return "Not Uploaded";
    switch (doc.verificationStatus.trim().toUpperCase()) {
      case "APPROVED":
        return "Approved";
      case "REJECTED":
        return "Rejected";
      case "PENDING":
      default:
        return "Pending";
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
}

class _DocumentCard extends StatelessWidget {
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
    required this.onUpload,
    required this.onView,
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
  final VoidCallback onUpload;
  final VoidCallback? onView;
  final String uploadLabel;

  @override
  Widget build(BuildContext context) {
    final displayRemarks = (remarks ?? "").trim();
    final displayHelper = (helperText ?? "").trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.cardShadow,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                  label: requiredLabel,
                  color: requiredColor,
                  textColor: Colors.white),
              StatusChip(
                  label: statusLabel,
                  color: statusColor,
                  textColor: Colors.white),
            ],
          ),
          if (displayHelper.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              displayHelper,
              style: TextStyle(
                color: helperColor ??
                    Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (displayRemarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Remarks: $displayRemarks",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(uploadLabel),
                ),
              ),
              if (onView != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isViewing ? null : onView,
                    icon: isViewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined),
                    label: const Text("View"),
                  ),
                ),
              ],
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.softShadow,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CV supports PDF, DOC, and DOCX. Other documents support PDF or image files based on document type. Maximum file size is 15 MB.",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            "NDT upload requires an expiry date. Selfie and signature support camera, gallery, or file selection. Other documents use a validated file picker.",
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600),
          ),
          if ((loadError ?? "").trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "API warning: $loadError",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCustomCard extends StatelessWidget {
  const _EmptyCustomCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
      ),
      child: Text(
        "No custom documents uploaded yet. Use Add More Document to upload an extra file.",
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700),
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
}

const List<_DocumentDefinition> _defaultDefinitions = <_DocumentDefinition>[
  _DocumentDefinition(
      type: "cv",
      displayName: "CV",
      isRequired: true,
      allowedExtensions: <String>["pdf", "doc", "docx"]),
  _DocumentDefinition(
      type: "ndt", displayName: "NDT Certificate", isRequired: true),
  _DocumentDefinition(
      type: "degree",
      displayName: "Degree / Diploma Certificate",
      isRequired: true),
  _DocumentDefinition(
    type: "selfie",
    displayName: "Selfie / Passport Size Photo",
    isRequired: true,
    allowPdf: false,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(type: "pan", displayName: "PAN Card", isRequired: true),
  _DocumentDefinition(
      type: "aadhaar", displayName: "Aadhaar Card", isRequired: true),
  _DocumentDefinition(
    type: "signature",
    displayName: "Signature Photo",
    isRequired: true,
    allowPdf: false,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(
      type: "appointment_letter",
      displayName: "Signed Appointment Letter",
      isRequired: true),
];

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
