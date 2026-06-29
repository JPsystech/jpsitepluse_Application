import "dart:io";
import "dart:typed_data";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:open_filex/open_filex.dart";
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../core/session_store.dart";
import "../../models/engineer_document_model.dart";
import "../../services/document_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/image_viewer.dart";
import "../../widgets/section_header.dart";
import "../../widgets/status_chip.dart";

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final DocumentService _service = DocumentService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  String? _loadError;
  List<EngineerDocument> _documents = <EngineerDocument>[];
  final Set<String> _busyKeys = <String>{};
  DateTime? _ndtExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadNdtExpiryDate();
    _loadDocuments();
  }

  String get _token => (SessionStore.current?.token ?? "").trim();

  List<EngineerDocument> get _customDocuments =>
      _documents.where((doc) => doc.normalizedType == "other").toList();

  Map<String, EngineerDocument> get _latestByType {
    final map = <String, EngineerDocument>{};
    for (final doc in _documents) {
      map.putIfAbsent(doc.normalizedType, () => doc);
    }
    return map;
  }

  Future<void> _loadDocuments({bool showLoader = true}) async {
    final token = _token;
    if (token.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = "Session expired. Please login again.";
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    } else {
      setState(() {
        _loadError = null;
      });
    }

    try {
      final docs = await _service.listDocuments(token: token);
      if (!mounted) return;
      setState(() {
        _documents = docs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addCustomDocument() async {
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
            onSubmitted: (_) => Navigator.of(dialogContext).pop(ctrl.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(ctrl.text.trim()),
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
      _showSnackBar(customError, isError: true);
      return;
    }

    await _handleUpload(
      definition: _customDefinition,
      customDocumentName: trimmed,
      busyKey: "custom::$trimmed",
    );
  }

  Future<void> _handleUpload({
    required _DocumentDefinition definition,
    required String busyKey,
    String? customDocumentName,
  }) async {
    if (_busyKeys.contains(busyKey)) return;

    DateTime? ndtExpiryDate;
    if (definition.type == "ndt") {
      ndtExpiryDate = await _pickNdtExpiryDate();
      if (ndtExpiryDate == null) return;
    }

    final selected = await _pickFile(definition);
    if (selected == null) return;

    final validationError = _validateSelectedFile(definition: definition, selected: selected, customDocumentName: customDocumentName);
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }

    final token = _token;
    if (token.isEmpty) {
      _showSnackBar("Session expired. Please login again.", isError: true);
      return;
    }

    setState(() {
      _busyKeys.add(busyKey);
    });

    try {
      await _service.uploadDocumentBytes(
        token: token,
        documentType: definition.type,
        documentName: customDocumentName ?? definition.displayName,
        bytes: selected.bytes,
        originalFileName: selected.fileName,
        contentType: selected.contentType,
        sizeBytes: selected.sizeBytes,
        fileExtension: selected.fileExtension,
      );
      if (!mounted) return;
      if (definition.type == "ndt" && ndtExpiryDate != null) {
        await _saveNdtExpiryDate(ndtExpiryDate);
      }
      _showSnackBar("Document uploaded successfully");
      await _loadDocuments(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyUploadError(e.toString());
      _showSnackBar(message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyKeys.remove(busyKey);
        });
      }
    }
  }

  Future<_SelectedUploadFile?> _pickFile(_DocumentDefinition definition) async {
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
                onTap: () => Navigator.of(context).pop(_DocumentPickSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Gallery"),
                onTap: () => Navigator.of(context).pop(_DocumentPickSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: const Text("Files"),
                onTap: () => Navigator.of(context).pop(_DocumentPickSource.files),
              ),
            ],
          ),
        ),
      );

      if (source == null) return null;
      switch (source) {
        case _DocumentPickSource.camera:
          return _pickWithImagePicker(ImageSource.camera);
        case _DocumentPickSource.gallery:
          return _pickWithImagePicker(ImageSource.gallery);
        case _DocumentPickSource.files:
          return _pickWithFilePicker(allowedExtensions: _pickerExtensionsForDefinition(definition));
      }
    }

    return _pickWithFilePicker(allowedExtensions: _pickerExtensionsForDefinition(definition));
  }

  Future<_SelectedUploadFile?> _pickWithFilePicker({required List<String> allowedExtensions}) async {
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
      _showSnackBar(_friendlyUploadError(e.toString()), isError: true);
      return null;
    }
  }

  Future<_SelectedUploadFile?> _pickWithImagePicker(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final name = file.name.trim().isEmpty ? file.path.split(Platform.pathSeparator).last : file.name.trim();
      return _prepareSelectedFile(
        fileName: name,
        bytes: bytes,
        explicitSize: bytes.length,
      );
    } catch (e) {
      _showSnackBar(_friendlyUploadError(e.toString()), isError: true);
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
    if (size > DocumentService.maxBytes) {
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

  Future<void> _loadNdtExpiryDate() async {
    final key = _ndtExpiryKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return;
    final parsed = DateTime.tryParse(raw);
    if (!mounted) return;
    setState(() {
      _ndtExpiryDate = parsed;
    });
  }

  Future<void> _saveNdtExpiryDate(DateTime date) async {
    final key = _ndtExpiryKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, DateTime(date.year, date.month, date.day).toIso8601String());
    if (!mounted) return;
    setState(() {
      _ndtExpiryDate = DateTime(date.year, date.month, date.day);
    });
  }

  String? get _ndtExpiryKey {
    final engineerId = (SessionStore.current?.engineer.id ?? "").trim();
    if (engineerId.isEmpty) return null;
    return "sitepulse_ndt_expiry_$engineerId";
  }

  Future<DateTime?> _pickNdtExpiryDate() async {
    final today = DateTime.now();
    final initial = _ndtExpiryDate ?? DateTime(today.year + 1, today.month, today.day);
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
    if (trimmed.length < 3) return "Document name must be at least 3 characters";
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
    if (definition.allowedExtensions.isNotEmpty) return definition.allowedExtensions;
    return definition.allowPdf ? const ["pdf", "jpg", "jpeg", "png"] : const ["jpg", "jpeg", "png"];
  }

  String? _ndtReminderText() {
    final expiry = _ndtExpiryDate;
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

  Color? _ndtReminderColor() {
    final expiry = _ndtExpiryDate;
    if (expiry == null) return null;
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final diffDays = expiry.difference(startToday).inDays;
    if (diffDays < 0) return AppTheme.danger;
    if (diffDays <= 30) return AppTheme.warning;
    return AppTheme.muted;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, "0");
    final m = date.month.toString().padLeft(2, "0");
    final y = date.year.toString().padLeft(4, "0");
    return "$d-$m-$y";
  }

  Future<void> _viewDocument(EngineerDocument document) async {
    final busyKey = "view::${document.id}";
    if (_busyKeys.contains(busyKey)) return;

    final url = document.fileUrl.trim();
    if (url.isEmpty) {
      _showSnackBar("No file is available to view", isError: true);
      return;
    }

    if (_isImageDocument(document)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageViewer(url: url)));
      return;
    }

    setState(() {
      _busyKeys.add(busyKey);
    });

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw "Failed to download file";
      }
      final tempDir = await getTemporaryDirectory();
      final name = document.effectiveFileName.isEmpty ? "document.pdf" : document.effectiveFileName;
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
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && result.message.trim().isNotEmpty) {
        throw result.message;
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Unable to open file. ${_friendlyUploadError(e.toString())}", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyKeys.remove(busyKey);
        });
      }
    }
  }

  bool _isImageDocument(EngineerDocument doc) {
    final ct = doc.contentType.trim().toLowerCase();
    if (ct.startsWith("image/")) return true;
    final ext = _extensionOf(doc.effectiveFileName);
    return ext == "jpg" || ext == "jpeg" || ext == "png";
  }

  String _friendlyUploadError(String message) {
    final cleaned = message.replaceFirst("Exception: ", "").trim();
    final lower = cleaned.toLowerCase();
    if (lower.contains("too large")) {
      return "File size too large. Please upload a file smaller than 15 MB.";
    }
    if (lower.contains("unsupported") || lower.contains("only jpg") || lower.contains("only png")) {
      return "Unsupported format. Please select an allowed document format.";
    }
    if (lower.contains("network") || lower.contains("unreachable")) {
      return "Internet/API error. Please check your connection and retry.";
    }
    return cleaned.isEmpty ? "Upload failed. Please try again." : cleaned;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestByType = _latestByType;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Documents"),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadDocuments(showLoader: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(18),
                child: ListView(
                  children: [
                    _InfoCard(loadError: _loadError),
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
                          requiredColor: _requiredColor(definition, doc),
                          statusLabel: _statusLabel(doc),
                          statusColor: _statusColor(doc),
                          remarks: doc?.adminRemarks,
                          helperText: definition.type == "ndt" ? _ndtReminderText() : null,
                          helperColor: definition.type == "ndt" ? _ndtReminderColor() : null,
                          isUploading: _busyKeys.contains(busyKey),
                          isViewing: doc != null && _busyKeys.contains("view::${doc.id}"),
                          onUpload: () => _handleUpload(definition: definition, busyKey: busyKey),
                          onView: doc != null && doc.fileUrl.trim().isNotEmpty ? () => _viewDocument(doc) : null,
                          uploadLabel: doc == null ? "Upload" : "Re-upload",
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    SectionHeader(
                      title: "Custom Documents",
                      trailing: OutlinedButton.icon(
                        onPressed: _addCustomDocument,
                        icon: const Icon(Icons.add),
                        label: const Text("Add More Document"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_customDocuments.isEmpty)
                      const _EmptyCustomCard()
                    else
                      ..._customDocuments.map((doc) {
                        final busyKey = "custom::${doc.documentName}";
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _DocumentCard(
                            title: doc.documentName,
                            requiredLabel: _requiredLabel(_customDefinition, doc),
                            requiredColor: _requiredColor(_customDefinition, doc),
                            statusLabel: _statusLabel(doc),
                            statusColor: _statusColor(doc),
                            remarks: doc.adminRemarks,
                            helperText: null,
                            helperColor: null,
                            isUploading: _busyKeys.contains(busyKey),
                            isViewing: _busyKeys.contains("view::${doc.id}"),
                            onUpload: () => _handleUpload(
                              definition: _customDefinition,
                              customDocumentName: doc.documentName,
                              busyKey: busyKey,
                            ),
                            onView: doc.fileUrl.trim().isNotEmpty ? () => _viewDocument(doc) : null,
                            uploadLabel: "Re-upload",
                          ),
                        );
                      }),
                    if (_loadError != null && _documents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Last refresh issue: $_loadError",
                        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  String _requiredLabel(_DocumentDefinition definition, EngineerDocument? doc) {
    final backend = (doc?.requiredLabel ?? "").trim();
    if (backend.isNotEmpty) return backend;
    final isRequired = doc?.isRequired ?? definition.isRequired;
    return isRequired ? "Required" : "Optional";
  }

  Color _requiredColor(_DocumentDefinition definition, EngineerDocument? doc) {
    final isRequired = doc?.isRequired ?? definition.isRequired;
    return isRequired ? AppTheme.sky : AppTheme.muted;
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

  Color _statusColor(EngineerDocument? doc) {
    if (doc == null) return AppTheme.muted;
    switch (doc.verificationStatus.trim().toUpperCase()) {
      case "APPROVED":
        return AppTheme.success;
      case "REJECTED":
        return AppTheme.danger;
      case "PENDING":
      default:
        return AppTheme.warning;
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
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.navy.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(label: requiredLabel, color: requiredColor, textColor: Colors.white),
              StatusChip(label: statusLabel, color: statusColor, textColor: Colors.white),
            ],
          ),
          if (displayHelper.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              displayHelper,
              style: TextStyle(
                color: helperColor ?? AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (displayRemarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Remarks: $displayRemarks",
              style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.navy.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CV supports PDF, DOC, and DOCX. Other documents support PDF or image files based on document type. Maximum file size is 15 MB.",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "NDT upload requires an expiry date. Selfie and signature support camera, gallery, or file selection. Other documents use a validated file picker.",
            style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
          ),
          if ((loadError ?? "").trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "API warning: $loadError",
              style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.navy.withAlpha(8)),
      ),
      child: const Text(
        "No custom documents uploaded yet. Use Add More Document to upload an extra file.",
        style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700),
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
  _DocumentDefinition(type: "cv", displayName: "CV", isRequired: true, allowedExtensions: <String>["pdf", "doc", "docx"]),
  _DocumentDefinition(type: "ndt", displayName: "NDT Certificate", isRequired: true),
  _DocumentDefinition(type: "degree", displayName: "Degree / Diploma Certificate", isRequired: true),
  _DocumentDefinition(
    type: "selfie",
    displayName: "Selfie / Passport Size Photo",
    isRequired: true,
    allowPdf: false,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(type: "pan", displayName: "PAN Card", isRequired: true),
  _DocumentDefinition(type: "aadhaar", displayName: "Aadhaar Card", isRequired: true),
  _DocumentDefinition(
    type: "signature",
    displayName: "Signature Photo",
    isRequired: true,
    allowPdf: false,
    allowsCameraOrGallery: true,
  ),
  _DocumentDefinition(type: "appointment_letter", displayName: "Signed Appointment Letter", isRequired: true),
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
