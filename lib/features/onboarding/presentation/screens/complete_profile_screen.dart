import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/features/documents/data/services/documents_service.dart';
import 'package:sitepulse_engineer/shared/models/engineer_document_model.dart';
import 'package:sitepulse_engineer/shared/widgets/primary_button.dart';
import '../../data/models/onboarding_status_model.dart';
import '../../data/services/onboarding_service.dart';

enum _DocPickSource { camera, gallery, files }

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentsService = DocumentsService();
  final _onboardingService = OnboardingService();

  int _currentStep = 0; // 0: Profile & Bank Details, 1: Compliance Documents
  bool _isLoading = true;
  bool _isSaving = false;
  String? _busyDocType;
  String? _deletingDocId;
  bool _hasAutoAdvancedToStep2 = false;

  OnboardingStatusModel? _status;
  List<EngineerDocument> _uploadedDocs = [];

  // Controllers
  final _dobController = TextEditingController();
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _accHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accNumController = TextEditingController();
  final _ifscController = TextEditingController();

  DateTime? _selectedDob;

  // Initial values to track dirty/unsaved state
  String _initialDob = '';
  String _initialPan = '';
  String _initialAadhaar = '';
  String _initialAccHolder = '';
  String _initialBankName = '';
  String _initialAccNum = '';
  String _initialIfsc = '';

  @override
  void initState() {
    super.initState();
    _initFieldsFromSession();
    _loadStatus();
  }

  @override
  void dispose() {
    _dobController.dispose();
    _panController.dispose();
    _aadhaarController.dispose();
    _accHolderController.dispose();
    _bankNameController.dispose();
    _accNumController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  void _initFieldsFromSession() {
    final engineer = SessionStore.current?.engineer;
    if (engineer == null) return;

    if (engineer.birthDate != null && engineer.birthDate!.isNotEmpty) {
      try {
        _selectedDob = DateTime.parse(engineer.birthDate!);
        _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDob!);
      } catch (_) {
        _dobController.text = engineer.birthDate!;
      }
    }
    _panController.text = (engineer.panCardNumber ?? '').toUpperCase();
    _aadhaarController.text = engineer.aadhaarCardNumber ?? '';
    _accHolderController.text =
        engineer.bankAccountHolderName ?? engineer.fullName;
    _bankNameController.text = engineer.bankName ?? '';
    _accNumController.text = engineer.bankAccountNumber ?? '';
    _ifscController.text = (engineer.bankIfscCode ?? '').toUpperCase();

    _syncInitialValues();
  }

  void _syncInitialValues() {
    _initialDob = _dobController.text.trim();
    _initialPan = _panController.text.trim();
    _initialAadhaar = _aadhaarController.text.trim();
    _initialAccHolder = _accHolderController.text.trim();
    _initialBankName = _bankNameController.text.trim();
    _initialAccNum = _accNumController.text.trim();
    _initialIfsc = _ifscController.text.trim();
  }

  bool get _hasUnsavedChanges {
    return _dobController.text.trim() != _initialDob ||
        _panController.text.trim() != _initialPan ||
        _aadhaarController.text.trim() != _initialAadhaar ||
        _accHolderController.text.trim() != _initialAccHolder ||
        _bankNameController.text.trim() != _initialBankName ||
        _accNumController.text.trim() != _initialAccNum ||
        _ifscController.text.trim() != _initialIfsc;
  }

  bool get _isStep1Complete {
    if (_status != null && _status!.missingFields.isNotEmpty) {
      return false;
    }
    return _dobController.text.trim().isNotEmpty &&
        _panController.text.trim().isNotEmpty &&
        _aadhaarController.text.trim().isNotEmpty &&
        _accHolderController.text.trim().isNotEmpty &&
        _bankNameController.text.trim().isNotEmpty &&
        _accNumController.text.trim().isNotEmpty &&
        _ifscController.text.trim().isNotEmpty;
  }

  bool get _isStep2Complete {
    if (_status == null) return false;
    if (_status!.requiredDocuments.isEmpty) return true;
    return _status!.missingDocuments.isEmpty;
  }

  bool get _isProfileComplete =>
      (_status?.isProfileComplete ?? false) ||
      (_isStep1Complete && _isStep2Complete);

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final session = SessionStore.current;
      if (session != null && session.token.isNotEmpty) {
        final statusFuture =
            _onboardingService.getOnboardingStatus(token: session.token);
        final docsFuture =
            _documentsService.listDocuments(token: session.token);

        final results = await Future.wait([statusFuture, docsFuture]);
        final status = results[0] as OnboardingStatusModel;
        final docs = results[1] as List<EngineerDocument>;

        if (mounted) {
          setState(() {
            _status = status;
            _uploadedDocs = docs;
            _isLoading = false;

            // Auto-advance to Step 2 if Step 1 details are already complete
            if (!_hasAutoAdvancedToStep2 &&
                status.missingFields.isEmpty &&
                status.missingDocuments.isNotEmpty) {
              _currentStep = 1;
              _hasAutoAdvancedToStep2 = true;
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    final initialDate = _selectedDob ?? DateTime(now.year - 25, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate:
          initialDate.isAfter(eighteenYearsAgo) ? eighteenYearsAgo : initialDate,
      firstDate: DateTime(1940),
      lastDate: eighteenYearsAgo,
      helpText: "Select Date of Birth",
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveProfileDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{};
      if (_selectedDob != null) {
        payload['birth_date'] = DateFormat('yyyy-MM-dd').format(_selectedDob!);
      } else if (_dobController.text.trim().isNotEmpty) {
        payload['birth_date'] = _dobController.text.trim();
      }

      final pan = _panController.text.trim().toUpperCase();
      if (pan.isNotEmpty) payload['pan_card_number'] = pan;

      final aadhaar = _aadhaarController.text.trim();
      if (aadhaar.isNotEmpty) payload['aadhaar_card_number'] = aadhaar;

      final accHolder = _accHolderController.text.trim();
      if (accHolder.isNotEmpty) payload['bank_account_holder_name'] = accHolder;

      final bankName = _bankNameController.text.trim();
      if (bankName.isNotEmpty) payload['bank_name'] = bankName;

      final accNum = _accNumController.text.trim();
      if (accNum.isNotEmpty) payload['bank_account_number'] = accNum;

      final ifsc = _ifscController.text.trim().toUpperCase();
      if (ifsc.isNotEmpty) payload['bank_ifsc_code'] = ifsc;

      final session = SessionStore.current;
      await _onboardingService.updateProfile(
        token: session?.token,
        data: payload,
      );

      // Sync session profile so updated values propagate app-wide
      await SessionStore.syncProfile();

      _syncInitialValues();

      if (mounted) {
        if (_isStep2Complete) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "🎉 Profile & Compliance completed! Attendance punch-in is unlocked."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Profile details saved! Please upload required compliance documents."),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _currentStep = 1;
        });
      }
      await _loadStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleCancelOrDiscard() async {
    if (_hasUnsavedChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Discard Changes?"),
          content: const Text(
            "You have unsaved changes to your profile details. If you discard and exit, your changes will not be saved and punch-in will remain locked.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Keep Editing"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Discard & Exit"),
            ),
          ],
        ),
      );
      if (shouldDiscard == true && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- Document Upload & Deletion Methods ---

  Future<void> _pickAndUploadDocument(String docType) async {
    final session = SessionStore.current;
    if (session == null || session.token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please log in again.")),
      );
      return;
    }

    final isCv = docType.toLowerCase() == "cv";
    Uint8List? fileBytes;
    String? fileName;

    if (isCv) {
      try {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
          withData: true,
        );
        if (res == null || res.files.isEmpty) return;
        final f = res.files.first;
        fileName = f.name;
        fileBytes = f.bytes;
        if (fileBytes == null && f.path != null) {
          fileBytes = await File(f.path!).readAsBytes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to pick document: $e")),
          );
        }
        return;
      }
    } else {
      final source = await showModalBottomSheet<_DocPickSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Upload ${OnboardingStatusModel.docDisplayName(docType)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text("Take Photo (Camera)"),
                  onTap: () => Navigator.of(bctx).pop(_DocPickSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text("Choose from Gallery"),
                  onTap: () => Navigator.of(bctx).pop(_DocPickSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text("Pick Document File (PDF / Image)"),
                  onTap: () => Navigator.of(bctx).pop(_DocPickSource.files),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      try {
        if (source == _DocPickSource.camera ||
            source == _DocPickSource.gallery) {
          final picker = ImagePicker();
          final picked = await picker.pickImage(
            source: source == _DocPickSource.camera
                ? ImageSource.camera
                : ImageSource.gallery,
            imageQuality: 80,
            maxWidth: 1800,
            maxHeight: 1800,
          );
          if (picked == null) return;
          fileName = picked.name.isNotEmpty
              ? picked.name
              : "doc_${DateTime.now().millisecondsSinceEpoch}.jpg";
          fileBytes = await picked.readAsBytes();
        } else {
          final res = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
            withData: true,
          );
          if (res == null || res.files.isEmpty) return;
          final f = res.files.first;
          fileName = f.name;
          fileBytes = f.bytes;
          if (fileBytes == null && f.path != null) {
            fileBytes = await File(f.path!).readAsBytes();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to select file: $e")),
          );
        }
        return;
      }
    }

    if (fileBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No file was selected.")),
        );
      }
      return;
    }

    final ext = _extensionOf(fileName);
    final contentType = _contentTypeForExtension(ext);
    if (contentType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unsupported format: .$ext")),
        );
      }
      return;
    }

    if (fileBytes.length > DocumentsService.maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File size exceeds 15 MB limit.")),
        );
      }
      return;
    }

    setState(() => _busyDocType = docType);

    try {
      final docDisplayName = OnboardingStatusModel.docDisplayName(docType);
      await _documentsService.uploadDocumentBytes(
        token: session.token,
        documentType: docType,
        documentName: docDisplayName,
        bytes: fileBytes,
        originalFileName: fileName,
        contentType: contentType,
        sizeBytes: fileBytes.length,
        fileExtension: ext,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$docDisplayName uploaded successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyDocType = null);
      }
    }
  }

  Future<void> _confirmDeleteDocument(EngineerDocument doc) async {
    final displayName = OnboardingStatusModel.docDisplayName(doc.documentType);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Submission?"),
        content: Text(
          "Are you sure you want to cancel and remove your uploaded $displayName?\n\nYou will need to re-upload this document to complete your profile.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Keep Document"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete / Cancel"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteDocument(doc);
    }
  }

  Future<void> _deleteDocument(EngineerDocument doc) async {
    setState(() => _deletingDocId = doc.id);
    try {
      final session = SessionStore.current;
      if (session == null || session.token.isEmpty) {
        throw Exception("Session expired. Please log in again.");
      }
      await _documentsService.deleteDocument(
        token: session.token,
        documentId: doc.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${OnboardingStatusModel.docDisplayName(doc.documentType)} submission removed.",
            ),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
      await _loadStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to remove document: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingDocId = null);
      }
    }
  }

  void _onFinish() {
    if (_isProfileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "🎉 Profile & Compliance completed! Attendance punch-in is unlocked."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Please upload all required compliance documents to unlock attendance."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

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

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentStep == 1) {
          setState(() => _currentStep = 0);
        } else {
          await _handleCancelOrDiscard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentStep == 0
                ? "Step 1: Profile & Bank Details"
                : "Step 2: Compliance Documents",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: false,
          leading: _currentStep == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: "Back to Profile Details",
                  onPressed: () => setState(() => _currentStep = 0),
                )
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: "Close",
                  onPressed: _handleCancelOrDiscard,
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildStepperHeader(context),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadStatus,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _currentStep == 0
                            ? _buildStep1ProfileView(context)
                            : _buildStep2DocumentsView(context),
                      ),
                    ),
                  ),
                  if (_currentStep == 1) _buildStep2BottomBar(context),
                ],
              ),
      ),
    );
  }

  Widget _buildStepperHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          // Step 1
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentStep = 0),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _buildStepBadge(
                      stepNumber: 1,
                      isActive: _currentStep == 0,
                      isComplete: _isStep1Complete,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Step 1",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _currentStep == 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Profile & Bank",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: _currentStep == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _currentStep == 0
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Divider Line
          Container(
            width: 28,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: _isStep1Complete ? Colors.green : colorScheme.outlineVariant,
          ),

          // Step 2
          Expanded(
            child: InkWell(
              onTap: () {
                if (_isStep1Complete || !_hasUnsavedChanges) {
                  setState(() => _currentStep = 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Please save your profile details first or complete required fields."),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _buildStepBadge(
                      stepNumber: 2,
                      isActive: _currentStep == 1,
                      isComplete: _isStep2Complete,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Step 2",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _currentStep == 1
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Documents",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: _currentStep == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _currentStep == 1
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge({
    required int stepNumber,
    required bool isActive,
    required bool isComplete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isComplete) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    }

    if (isActive) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            "$stepNumber",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          "$stepNumber",
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // --- STEP 1: Profile & Bank Details View ---

  Widget _buildStep1ProfileView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStep1HeaderBanner(context),
          const SizedBox(height: 16),

          // Card 1: Statutory & Personal Info
          _buildSectionCard(
            context,
            title: "Personal & Statutory Details",
            icon: Icons.person_outline_rounded,
            children: [
              // Date of Birth
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Date of Birth *",
                  hintText: "YYYY-MM-DD",
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: _selectDob,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: _selectDob,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Date of birth is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // PAN Card
              TextFormField(
                controller: _panController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: "PAN Card Number *",
                  hintText: "ABCDE1234F",
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "PAN number is required";
                  }
                  final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
                  if (!panPattern.hasMatch(v.trim().toUpperCase())) {
                    return "Invalid PAN format (e.g. ABCDE1234F)";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Aadhaar Card
              TextFormField(
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: "Aadhaar Card Number *",
                  hintText: "12 digits",
                  prefixIcon: const Icon(Icons.fingerprint_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Aadhaar number is required";
                  }
                  if (v.trim().length != 12) {
                    return "Aadhaar must be exactly 12 digits";
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card 2: Bank Account Details
          _buildSectionCard(
            context,
            title: "Bank Account Details",
            icon: Icons.account_balance_outlined,
            children: [
              // Account Holder
              TextFormField(
                controller: _accHolderController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: "Account Holder Name *",
                  hintText: "Name as per passbook",
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Account holder name is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bank Name
              TextFormField(
                controller: _bankNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: "Bank Name *",
                  hintText: "e.g. State Bank of India",
                  prefixIcon: const Icon(Icons.account_balance_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Bank name is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Account Number
              TextFormField(
                controller: _accNumController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(30),
                ],
                decoration: InputDecoration(
                  labelText: "Account Number *",
                  hintText: "Enter bank account number",
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Account number is required";
                  }
                  if (v.trim().length < 6) {
                    return "Account number must have at least 6 digits";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // IFSC Code
              TextFormField(
                controller: _ifscController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: "Bank IFSC Code *",
                  hintText: "e.g. SBIN0123456",
                  prefixIcon: const Icon(Icons.domain_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "IFSC code is required";
                  }
                  final ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                  if (!ifscPattern.hasMatch(v.trim().toUpperCase())) {
                    return "Invalid IFSC format (e.g. SBIN0123456)";
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Step 1 Bottom Action Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _handleCancelOrDiscard,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: PrimaryButton(
                  label: _isStep2Complete
                      ? "Save & Unlock Attendance 🎉"
                      : "Save & Continue →",
                  isLoading: _isSaving,
                  icon: _isStep2Complete
                      ? Icons.lock_open_rounded
                      : Icons.arrow_forward_rounded,
                  backgroundColor:
                      _isStep2Complete ? Colors.green.shade700 : null,
                  onPressed: _isSaving ? null : _saveProfileDetails,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep1HeaderBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isStep1Complete) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Personal & bank details are complete.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isStep2Complete) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded,
                color: Colors.blue.shade800, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "All compliance documents are already uploaded! Please complete your remaining profile & bank details below to unlock attendance punch-in.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Please complete your statutory and bank details below, then tap Save & Continue.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  // --- STEP 2: Compliance Documents View ---

  Widget _buildStep2DocumentsView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final requiredDocs = _status?.requiredDocuments ?? const [];
    final department = _status?.department ?? "General";
    final uploadedTypes = _status?.uploadedDocuments ?? const [];

    final uploadedCount = requiredDocs.where((d) => uploadedTypes.contains(d)).length;
    final totalCount = requiredDocs.length;
    final pct = totalCount > 0 ? (uploadedCount / totalCount) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isStep2Complete ? Colors.green.shade300 : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      department.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "$uploadedCount of $totalCount Uploaded",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isStep2Complete ? Colors.green.shade800 : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isStep2Complete ? Colors.green : Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isStep2Complete
                    ? "All required compliance documents have been submitted!"
                    : "Compliance rules for your department mandate uploading the following documents to unlock attendance punch-in.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text(
          "Required Department Documents",
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        if (requiredDocs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text("No document requirements found for your department.")),
          )
        else
          ...requiredDocs.map((docType) {
            // Find latest matching uploaded document
            final match = _uploadedDocs.where((d) => d.normalizedType == docType.toLowerCase());
            final doc = match.isNotEmpty ? match.first : null;
            return _buildDocumentTile(context, docType: docType, uploadedDoc: doc);
          }),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDocumentTile(
    BuildContext context, {
    required String docType,
    required EngineerDocument? uploadedDoc,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final docTitle = OnboardingStatusModel.docDisplayName(docType);

    final isBusyUploading = _busyDocType == docType;
    final isBusyDeleting = uploadedDoc != null && _deletingDocId == uploadedDoc.id;

    final isUploaded = uploadedDoc != null;
    final status = uploadedDoc?.verificationStatus.toUpperCase() ?? "NOT_UPLOADED";
    final isApproved = status == "APPROVED";
    final isRejected = status == "REJECTED";
    final isPending = isUploaded && !isApproved && !isRejected;

    Color cardBorderColor = colorScheme.outlineVariant;
    if (isApproved) cardBorderColor = Colors.green.shade300;
    if (isRejected) cardBorderColor = Colors.red.shade300;
    if (isPending) cardBorderColor = Colors.amber.shade300;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isApproved
                      ? Icons.check_circle_rounded
                      : isRejected
                          ? Icons.cancel_rounded
                          : isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.description_outlined,
                  color: isApproved
                      ? Colors.green
                      : isRejected
                          ? Colors.red
                          : isPending
                              ? Colors.amber.shade800
                              : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isUploaded && uploadedDoc.originalFilename != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            uploadedDoc.originalFilename!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  isApproved: isApproved,
                  isRejected: isRejected,
                  isPending: isPending,
                ),
              ],
            ),

            // Rejected Remarks Box
            () {
              final remarks = uploadedDoc?.adminRemarks;
              if (isRejected && remarks != null && remarks.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Admin Remark: $remarks",
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }(),

            // Busy Loader
            if (isBusyUploading || isBusyDeleting) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text(
                isBusyUploading ? "Uploading document..." : "Cancelling submission...",
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              // Document Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isUploaded) ...[
                    FilledButton.tonalIcon(
                      onPressed: () => _pickAndUploadDocument(docType),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text("Upload Document"),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ] else if (!isApproved) ...[
                    // Cancel / Delete Submission Button
                    TextButton.icon(
                      onPressed: () => _confirmDeleteDocument(uploadedDoc),
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      label: const Text(
                        "Cancel Submission",
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Replace Button
                    OutlinedButton.icon(
                      onPressed: () => _pickAndUploadDocument(docType),
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text("Replace", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "Verified by Admin",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required bool isApproved,
    required bool isRejected,
    required bool isPending,
  }) {
    if (isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Approved",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade900,
          ),
        ),
      );
    }
    if (isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Rejected",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade900,
          ),
        ),
      );
    }
    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Pending Review",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade900,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "Required",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  // --- STEP 2 Bottom Persistent Bar ---

  Widget _buildStep2BottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final missingCount = _status?.missingDocuments.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text("Profile"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isProfileComplete
                  ? PrimaryButton(
                      label: "Finish & Unlock Attendance",
                      icon: Icons.lock_open_rounded,
                      backgroundColor: Colors.green.shade700,
                      onPressed: _onFinish,
                    )
                  : PrimaryButton(
                      label: missingCount > 0
                          ? "$missingCount Document(s) Remaining"
                          : "Finish & Unlock",
                      icon: Icons.lock_clock_rounded,
                      backgroundColor: Colors.amber.shade900,
                      onPressed: _onFinish,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
