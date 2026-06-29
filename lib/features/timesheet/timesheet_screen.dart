import "dart:io";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:image_picker/image_picker.dart";

import "../../core/ist_time.dart";
import "../../models/today_assignment.dart";
import "../../services/assignment_service.dart";
import "../../services/site_photo_service.dart";
import "../../widgets/app_text_field.dart";
import "../../widgets/primary_button.dart";
import "../../widgets/section_header.dart";
import "../../theme/app_theme.dart";

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key, required this.sessionToken, required this.engineerEmpCode});

  final String sessionToken;
  final String engineerEmpCode;

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  final descriptionCtrl = TextEditingController();
  final hoursCtrl = TextEditingController(text: "8");

  bool isLoading = true;
  bool isSubmitting = false;
  String? error;
  String? projectName;
  String? siteName;
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
  void initState() {
    super.initState();
    _loadAssignment();
  }

  @override
  void dispose() {
    descriptionCtrl.dispose();
    hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssignment() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final resp = await AssignmentService().todayAssignment(token: widget.sessionToken);
      TodayAssignment? a = resp.assignment;
      if (resp.assignments.isNotEmpty) {
        final activePid = (resp.activeProjectId ?? "").trim();
        if (activePid.isNotEmpty) {
          a = resp.assignments.firstWhere((x) => x.projectId == activePid, orElse: () => resp.assignments.first);
        } else {
          a = resp.assignments.first;
        }
      }
      setState(() {
        projectName = a?.projectName;
        siteName = a?.siteName;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _fmtDate(DateTime dt) => IstTime.formatDate(dt);
  String _fmtTimeWithSeconds(DateTime dt) {
    final v = IstTime.toIst(dt);
    final h = v.hour.toString().padLeft(2, "0");
    final m = v.minute.toString().padLeft(2, "0");
    final s = v.second.toString().padLeft(2, "0");
    return "$h:$m:$s";
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
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    }
  }

  Future<({double lat, double lng})> _resolveLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw "Location services are disabled";
    }

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

  int _parseHours() {
    final raw = hoursCtrl.text.trim();
    if (raw.isEmpty) return 0;
    final v = double.tryParse(raw);
    if (v == null) return 0;
    return (v * 60).round();
  }

  Future<void> submit() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
      error = null;
    });

    try {
      final desc = descriptionCtrl.text.trim();
      final mins = _parseHours();
      if (desc.isEmpty) {
        throw "Work description is required";
      }
      if (mins <= 0) {
        throw "Hours must be greater than 0";
      }
      if (photo == null) {
        throw "Please upload a photo";
      }

      final loc = await _resolveLocation();
      final hoursText = (mins / 60).toStringAsFixed(mins % 60 == 0 ? 0 : 1);
      final addressText = "$activityType • ${hoursText}h • $desc";

      final fileUrl = await SitePhotoService().uploadProgressPhoto(
        token: widget.sessionToken,
        file: photo!,
        lat: loc.lat,
        lng: loc.lng,
        addressText: addressText,
        projectName: (projectName ?? "-").trim().isEmpty ? "-" : projectName!.trim(),
        siteName: (siteName ?? "-").trim().isEmpty ? "-" : siteName!.trim(),
        empCode: widget.engineerEmpCode.trim().isEmpty ? "-" : widget.engineerEmpCode.trim(),
        capturedAt: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work update submitted")));
      setState(() {
        descriptionCtrl.text = "";
        hoursCtrl.text = "8";
        activityType = activityTypes.first;
        photo = null;
        uploadedPhotoUrl = fileUrl;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = IstTime.now();
    final pn = (projectName ?? "").trim();
    final sn = (siteName ?? "").trim();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Work Update"),
        actions: [
          IconButton(onPressed: isLoading ? null : _loadAssignment, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Padding(
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
                                Text(_fmtDate(today), style: const TextStyle(fontWeight: FontWeight.w900)),
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
                                              Text("${(projectName ?? "-").trim()} | ${(siteName ?? "-").trim()}"),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Date: ${IstTime.formatDate(DateTime.now())}    Time: ${_fmtTimeWithSeconds(DateTime.now())}",
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
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.danger.withAlpha(40)),
                        ),
                        child: Text(error!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(label: "Submit Work Update", onPressed: isSubmitting ? null : submit, isLoading: isSubmitting, icon: Icons.send),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
