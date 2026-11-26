import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/shared/widgets/app_form_fields.dart';
import 'package:sitepulse_engineer/shared/widgets/app_date_picker.dart';
import 'package:sitepulse_engineer/shared/widgets/app_file_upload_card.dart';

class SignedAttendanceSheetsScreen extends StatefulWidget {
  const SignedAttendanceSheetsScreen({super.key});

  @override
  State<SignedAttendanceSheetsScreen> createState() => _SignedAttendanceSheetsScreenState();
}

class _SignedAttendanceSheetsScreenState extends State<SignedAttendanceSheetsScreen> {
  final _remarks = TextEditingController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _sheets = [];
  String? _projectId;
  PlatformFile? _file;
  bool _loading = true;
  bool _saving = false;

  String get _monthKey => DateFormat('yyyy-MM').format(_month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  void _notice(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = await ApiClient.instance.dio;
      final responses = await Future.wait([
        dio.get('/api/v1/engineer/signed-attendance-sheets'),
        dio.get('/api/v1/engineer/signed-attendance-sheets/eligible-projects', queryParameters: {'attendance_month': _monthKey}),
      ]);
      if (!mounted) return;
      setState(() {
        _sheets = (responses[0].data as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        _projects = (responses[1].data as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        if (!_projects.any((project) => project['id'] == _projectId)) _projectId = null;
      });
    } catch (_) {
      _notice('Could not load signed attendance sheets.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseMonth() async {
    final picked = await showAppDatePicker(context: context, initialDate: _month, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 366)));
    if (picked == null) return;
    _month = DateTime(picked.year, picked.month);
    await _load();
  }

  Future<void> _chooseFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    if (picked == null) return;
    final file = picked.files.single;
    if (file.size > 10 * 1024 * 1024) return _notice('Files must be 10 MB or smaller.');
    setState(() => _file = file);
  }

  Future<bool> _upload() async {
    if (_projectId == null || _file?.bytes == null) {
      _notice('Choose an assigned project and a signed file.');
      return false;
    }
    setState(() => _saving = true);
    try {
      final ext = _file!.name.split('.').last.toLowerCase();
      final contentType = ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
      final dio = await ApiClient.instance.dio;
      await dio.post('/api/v1/engineer/signed-attendance-sheets', data: FormData.fromMap({
        'project_id': _projectId,
        'attendance_month': _monthKey,
        'remarks': _remarks.text.trim(),
        'file': MultipartFile.fromBytes(_file!.bytes! as Uint8List, filename: _file!.name, contentType: DioMediaType.parse(contentType)),
      }));
      if (!mounted) return false;
      _remarks.clear();
      setState(() => _file = null);
      _notice('Signed attendance sheet uploaded for verification.');
      await _load();
      return true;
    } on DioException catch (error) {
      _notice(error.response?.data is Map ? '${error.response?.data['detail']}' : 'Upload failed.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUploadSheet() async {
    String? projectError;
    String? fileError;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Upload signed attendance sheet', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Select the attendance month and assigned project, then attach the client-signed sheet.', style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              AppPickerField(
                label: 'Attendance month',
                value: DateFormat('MMMM yyyy').format(_month),
                enabled: !_saving,
                onTap: () async { await _chooseMonth(); setSheetState(() {}); },
              ),
              const SizedBox(height: 12),
              AppDropdownField<String>(
                value: _projectId,
                label: 'Assigned project',
                errorText: projectError,
                items: _projects.map((project) => DropdownMenuItem(value: '${project['id']}', child: Text('${project['project_name']} - ${project['site_name']}', overflow: TextOverflow.ellipsis))).toList(),
                enabled: !_saving,
                onChanged: (value) => setSheetState(() { _projectId = value; projectError = null; }),
              ),
              const SizedBox(height: 12),
              AppFileUploadCard(
                uploadLabel: 'Tap to Upload Client-Signed Sheet',
                supportText: 'Supports PDF, JPG, JPEG, PNG up to 10 MB',
                fileName: _file?.name,
                fileSizeBytes: _file?.size,
                enabled: !_saving,
                onTap: () async {
                  await _chooseFile();
                  setSheetState(() {
                    if (_file != null) fileError = null;
                  });
                },
                onClear: () => setSheetState(() {
                  _file = null;
                  fileError = null;
                }),
              ),
              if (fileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    fileError!,
                    style: TextStyle(color: Theme.of(sheetContext).colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              AppTextArea(label: 'Remarks (optional)', controller: _remarks, enabled: !_saving),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: _saving ? null : () => Navigator.of(sheetContext).pop(), child: const Text('Cancel')),
                FilledButton(onPressed: _saving ? null : () async {
                  if (_projectId == null || _file?.bytes == null) {
                    setSheetState(() { projectError = _projectId == null ? 'Choose an assigned project.' : null; fileError = _file?.bytes == null ? 'Attach the client-signed sheet.' : null; });
                    return;
                  }
                  setSheetState(() {});
                  if (await _upload() && sheetContext.mounted) Navigator.of(sheetContext).pop();
                  else if (sheetContext.mounted) setSheetState(() {});
                }, child: Text(_saving ? 'Uploading...' : 'Upload signed sheet')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signed Attendance Sheets')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Upload signed sheet',
        onPressed: _loading ? null : _openUploadSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('My uploads', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Track each signed attendance sheet and its review status.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  if (_sheets.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 12), child: Text('No signed attendance sheets uploaded yet.'))
                  else
                    ..._sheets.map((sheet) => Card(
                      child: ListTile(
                        title: Text('${sheet['project_name']} - ${sheet['attendance_month']}'),
                        subtitle: Text('v${sheet['version']} - ${sheet['original_filename']}${sheet['admin_remarks'] != null ? '\nAdmin: ${sheet['admin_remarks']}' : ''}'),
                        isThreeLine: sheet['admin_remarks'] != null,
                        trailing: Chip(label: Text('${sheet['status']}')),
                      ),
                    )),
                ],
              ),
            ),
    );
  }
}
