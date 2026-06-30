import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:geolocator/geolocator.dart";
import "package:image_picker/image_picker.dart";

import "package:sitepulse_engineer/core/utils/ist_time.dart";
import "package:sitepulse_engineer/core/utils/formatters.dart";
import "package:sitepulse_engineer/shared/widgets/app_text_field.dart";
import "package:sitepulse_engineer/shared/widgets/primary_button.dart";
import "package:sitepulse_engineer/shared/widgets/section_header.dart";
import "package:sitepulse_engineer/core/theme/app_theme.dart";
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
      create: (_) => TimesheetBloc()..add(LoadTimesheetDataRequested(sessionToken: sessionToken)),
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
  final hoursCtrl = TextEditingController(text: "8");

  String activityType = "Work";
  File? photo;
  String? uploadedPhotoUrl;

  static const activityTypes = <String>[
    "Work",
    "Inspection",
    "Maintenance",
    "Installation",
    "Meeting",
    "Travel",
    "Other",
  ];

  @override
  void dispose() {
    descriptionCtrl.dispose();
    hoursCtrl.dispose();
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
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<({double lat, double lng})> _resolveLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw "Location services are disabled";

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) throw "Location permission is required";
    if (perm == LocationPermission.deniedForever) {
      throw "Location permission is denied permanently. Enable it in Settings.";
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  }

  int _parseHours() {
    final raw = hoursCtrl.text.trim();
    if (raw.isEmpty) return 0;
    final v = double.tryParse(raw);
    if (v == null) return 0;
    return (v * 60).round();
  }

  Future<void> submit() async {
    try {
      final desc = descriptionCtrl.text.trim();
      final mins = _parseHours();
      if (desc.isEmpty) throw "Work description is required";
      if (mins <= 0) throw "Hours must be greater than 0";
      if (photo == null) throw "Please upload a photo";

      final loc = await _resolveLocation();

      if (!mounted) return;
      final bloc = context.read<TimesheetBloc>();

      
      bloc.add(SubmitTimesheetRequested(
        sessionToken: widget.sessionToken,
        engineerEmpCode: widget.engineerEmpCode,
        photo: photo!,
        description: desc,
        minutes: mins,
        activityType: activityType,
        lat: loc.lat,
        lng: loc.lng,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = IstTime.now();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Work Update"),
        actions: [
          BlocBuilder<TimesheetBloc, TimesheetState>(
            builder: (context, state) {
              final isLoading = state.status == TimesheetStatus.loading || state.status == TimesheetStatus.initial;
              return IconButton(
                onPressed: isLoading
                    ? null
                    : () {
                        context.read<TimesheetBloc>().add(LoadTimesheetDataRequested(sessionToken: widget.sessionToken));
                      },
                icon: const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<TimesheetBloc, TimesheetState>(
          listener: (context, state) {
            if (state.status == TimesheetStatus.submitSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work update submitted")));
              setState(() {
                descriptionCtrl.text = "";
                hoursCtrl.text = "8";
                activityType = activityTypes.first;
                photo = null;
                uploadedPhotoUrl = state.uploadedPhotoUrl;
              });
            } else if (state.status == TimesheetStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppTheme.danger,
              ));
            }
          },
          builder: (context, state) {
            final isLoading = state.status == TimesheetStatus.loading || state.status == TimesheetStatus.initial;
            final isSubmitting = state.status == TimesheetStatus.submitting;
            
            final pn = state.projectName.trim();
            final sn = state.siteName.trim();

            return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: "New Work Update"),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Date", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(AppFormatters.formatDate(today), style: const TextStyle(fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                              if (isLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text("Project / Site", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(pn.isEmpty ? "-" : pn, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(sn.isEmpty ? "-" : sn, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        const SectionHeader(title: "Work Details"),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Work description", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: descriptionCtrl,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    hintText: "What work update do you want to submit?",
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text("Activity type", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: activityType,
                                  items: activityTypes
                                      .map((t) => DropdownMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700))))
                                      .toList(),
                                  onChanged: isSubmitting ? null : (v) => setState(() => activityType = v ?? activityTypes.first),
                                  decoration: const InputDecoration(),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text("Hours", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                                    ),
                                    TextButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : () {
                                              final raw = hoursCtrl.text.trim();
                                              final v = double.tryParse(raw) ?? 0;
                                              final next = (v - 0.5).clamp(0, 24);
                                              setState(() => hoursCtrl.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1));
                                            },
                                      child: const Text("-0.5h"),
                                    ),
                                    TextButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : () {
                                              final raw = hoursCtrl.text.trim();
                                              final v = double.tryParse(raw) ?? 0;
                                              final next = (v + 0.5).clamp(0, 24);
                                              setState(() => hoursCtrl.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1));
                                            },
                                      child: const Text("+0.5h"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                AppTextField(
                                  label: "Hours",
                                  controller: hoursCtrl,
                                  showLabel: false,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textInputAction: TextInputAction.next,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SectionHeader(title: "Photo"),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text("Upload photo", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                                    ),
                                    TextButton(onPressed: isSubmitting ? null : _pickPhoto, child: const Text("Capture")),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (photo == null)
                                  uploadedPhotoUrl == null
                                      ? const Text("No photo selected", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600))
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(uploadedPhotoUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
                                        )
                                else
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Image.file(photo!, height: 180, width: double.infinity, fit: BoxFit.cover),
                                        Positioned(
                                          left: 10,
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(153),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: DefaultTextStyle(
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("${pn.isEmpty ? "-" : pn} | ${sn.isEmpty ? "-" : sn}"),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Date: ${AppFormatters.formatDate(DateTime.now())}    Time: ${AppFormatters.formatTimeWithSeconds(DateTime.now())}",
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text("Emp: ${widget.engineerEmpCode.trim().isEmpty ? "-" : widget.engineerEmpCode.trim()}",
                                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: "Submit Work Update",
                          onPressed: isSubmitting ? null : submit,
                          isLoading: isSubmitting,
                          icon: Icons.send,
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
