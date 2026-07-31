import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:geolocator/geolocator.dart";
import "package:image_picker/image_picker.dart";

import "package:sitepulse_engineer/core/utils/ist_time.dart";
import "package:sitepulse_engineer/core/utils/formatters.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";
import "package:sitepulse_engineer/core/services/offline_punch_queue.dart";
import "package:sitepulse_engineer/core/config/api_config.dart";

import "package:sitepulse_engineer/features/timesheet/presentation/bloc/timesheet_bloc.dart";

class TimesheetScreen extends StatelessWidget {
  const TimesheetScreen({
    super.key,
    required this.sessionToken,
    required this.engineerEmpCode,
  });

  final String sessionToken;
  final String engineerEmpCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TimesheetBloc()
        ..add(LoadTimesheetDataRequested(sessionToken: sessionToken)),
      child: _TimesheetView(
        sessionToken: sessionToken,
        engineerEmpCode: engineerEmpCode,
      ),
    );
  }
}

class _TimesheetView extends StatefulWidget {
  const _TimesheetView({
    required this.sessionToken,
    required this.engineerEmpCode,
  });

  final String sessionToken;
  final String engineerEmpCode;

  @override
  State<_TimesheetView> createState() => _TimesheetViewState();
}

class _TimesheetViewState extends State<_TimesheetView> {
  final descriptionCtrl = TextEditingController();

  File? photo;
  String? uploadedPhotoUrl;

  String? descError;
  String? photoError;

  @override
  void dispose() {
    descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (xfile == null) return;
      setState(() {
        photo = File(xfile.path);
        uploadedPhotoUrl = null;
        photoError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["pdf"],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      setState(() {
        photo = File(path);
        uploadedPhotoUrl = null;
        photoError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showAttachmentSourceOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: cs.primary),
                title: const Text("Capture Site Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto();
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_rounded, color: cs.error),
                title: const Text("Upload PDF Report"),
                onTap: () {
                  Navigator.pop(context);
                  _pickPdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<({double lat, double lng})> _resolveLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw "Location services are disabled";

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw "Location permission is required";
    }
    if (perm == LocationPermission.deniedForever) {
      throw "Location permission is denied permanently. Enable it in Settings.";
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  }

  Future<void> submit() async {
    try {
      final desc = descriptionCtrl.text.trim();

      setState(() {
        descError = desc.isEmpty ? "Work description is required" : null;
        photoError = photo == null && uploadedPhotoUrl == null
            ? "Please capture a photo or upload a PDF report"
            : null;
      });

      if (descError != null || photoError != null) return;

      final loc = await _resolveLocation();

      if (!mounted) return;
      final bloc = context.read<TimesheetBloc>();

      bloc.add(SubmitTimesheetRequested(
        sessionToken: widget.sessionToken,
        engineerEmpCode: widget.engineerEmpCode,
        photo: photo!,
        description: desc,
        minutes: 0,
        activityType: "Work",
        lat: loc.lat,
        lng: loc.lng,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = IstTime.now();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: cs.surface,
        scrolledUnderElevation: 1,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Work Update",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Track all completed work activities",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: BlocConsumer<TimesheetBloc, TimesheetState>(
          listener: (context, state) {
            if (state.status == TimesheetStatus.submitSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Work update submitted")));
              setState(() {
                descriptionCtrl.text = "";
                photo = null;
                uploadedPhotoUrl = null;
                descError = null;
                photoError = null;
              });
            } else if (state.status == TimesheetStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Theme.of(context).colorScheme.error,
              ));
            }
          },
          builder: (context, state) {
            final isLoading = state.status == TimesheetStatus.loading ||
                state.status == TimesheetStatus.initial;
            final isSubmitting = state.status == TimesheetStatus.submitting;

            final pn = state.projectName.trim();
            final sn = state.siteName.trim();

            return RefreshIndicator(
              onRefresh: () async {
                context.read<TimesheetBloc>().add(
                    LoadTimesheetDataRequested(
                        sessionToken: widget.sessionToken));
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<int>(
                    future: OfflinePunchQueue().count(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(top: 16, bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).extension<AppColorsExtension>()!.warningBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).extension<AppColorsExtension>()!.warning.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Theme.of(context).extension<AppColorsExtension>()!.warning, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Offline Mode Active", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).extension<AppColorsExtension>()!.warning)),
                                  Text("$count punches pending sync", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).extension<AppColorsExtension>()!.warning.withAlpha(200))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppFormatters.formatDate(today),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (isLoading)
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          pn.isEmpty ? "-" : pn,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_rounded, size: 18, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sn.isEmpty ? "-" : sn,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _buildWorkDetailsList(context, isSubmitting, isLoading, pn, sn),
                  ),
                ],
              ),
              )
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkDetailsList(BuildContext context, bool isSubmitting, bool isLoading, String pn, String sn) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Text(
          "Work Description",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionCtrl,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => setState(() => descError = null),
          decoration: InputDecoration(
            hintText: "What work did you complete?",
            errorText: descError,
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Site Photo / PDF Report",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photo == null && uploadedPhotoUrl == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, size: 48, color: cs.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          "No photo or PDF report selected",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: isSubmitting ? null : _pickPhoto,
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text("Capture Photo"),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: isSubmitting ? null : _pickPdf,
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              label: const Text("Upload PDF"),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      if (photo != null && photo!.path.toLowerCase().endsWith('.pdf'))
                        Container(
                          height: 240,
                          width: double.infinity,
                          color: cs.errorContainer.withValues(alpha: 0.2),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 64, color: cs.error),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    photo!.path.split(Platform.pathSeparator).last,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onErrorContainer,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "PDF Document Selected",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (uploadedPhotoUrl != null && uploadedPhotoUrl!.toLowerCase().split('?').first.endsWith('.pdf'))
                        Container(
                          height: 240,
                          width: double.infinity,
                          color: cs.errorContainer.withValues(alpha: 0.2),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 64, color: cs.error),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    "PDF Report",
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onErrorContainer,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "PDF Document Submitted",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (photo != null)
                        Image.file(photo!, height: 240, width: double.infinity, fit: BoxFit.cover)
                      else if (uploadedPhotoUrl != null)
                        Image.network(resolveMaybeRelativeUrl(uploadedPhotoUrl!), height: 240, width: double.infinity, fit: BoxFit.cover),
                      
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${pn.isEmpty ? "-" : pn} | ${sn.isEmpty ? "-" : sn}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Time: ${AppFormatters.formatTimeWithSeconds(DateTime.now())}",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                              ),
                              Text(
                                "Emp: ${widget.engineerEmpCode.trim().isEmpty ? "-" : widget.engineerEmpCode.trim()}",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton.filled(
                          onPressed: isSubmitting ? null : _showAttachmentSourceOptions,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (photoError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
                      const SizedBox(width: 8),
                      Text(
                        photoError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: isSubmitting ? null : submit,
            icon: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
            label: Text(isSubmitting ? "Submitting..." : "Submit Work Update", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }
}
