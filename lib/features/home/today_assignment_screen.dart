import "dart:math";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";

import "../../core/ist_time.dart";
import "../../models/today_assignment.dart";
import "../../services/api_client.dart";
import "../../services/assignment_service.dart";
import "../../services/offline_punch_queue.dart";
import "../timeline/activity_timeline_screen.dart";
import "../timesheet/timesheet_screen.dart";
import "../../widgets/primary_button.dart";
import "../../widgets/section_header.dart";
import "../../widgets/status_chip.dart";
import "../../widgets/shimmer_box.dart";
import "../../theme/app_theme.dart";

class TodayAssignmentScreen extends StatefulWidget {
  const TodayAssignmentScreen({super.key, required this.sessionToken, required this.engineerName, required this.engineerEmpCode});

  final String sessionToken;
  final String engineerName;
  final String engineerEmpCode;

  @override
  State<TodayAssignmentScreen> createState() => _TodayAssignmentScreenState();
}

class _TodayAssignmentScreenState extends State<TodayAssignmentScreen> {
  bool isLoading = true;
  String? error;
  TodayAssignmentResponse? data;
  bool isPunchingIn = false;
  bool isPunchingOut = false;
  String? actionError;
  String? selectedProjectId;
  int pendingOfflineCount = 0;
  bool pendingOfflineIn = false;
  bool pendingOfflineOut = false;
  final OfflinePunchQueue _offlineQueue = OfflinePunchQueue();

  @override
  void initState() {
    super.initState();
    _refreshOfflineState();
    _load();
  }

  Future<void> _refreshOfflineState() async {
    final items = await _offlineQueue.list();
    if (!mounted) return;
    setState(() {
      pendingOfflineCount = items.length;
      pendingOfflineIn = items.any((p) => p.type == OfflinePunchType.inPunch);
      pendingOfflineOut = items.any((p) => p.type == OfflinePunchType.outPunch);
    });
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
      actionError = null;
    });
    try {
      final resp = await AssignmentService().todayAssignment(token: widget.sessionToken);
      setState(() {
        data = resp;
        final activePid = (resp.activeProjectId ?? "").trim();
        final nextAssignments = resp.assignments;
        final selectedStillValid = nextAssignments.any((a) => a.projectId == (selectedProjectId ?? ""));
        if (activePid.isNotEmpty) {
          selectedProjectId = activePid;
        } else if (!selectedStillValid) {
          selectedProjectId = nextAssignments.isNotEmpty ? nextAssignments.first.projectId : null;
        }
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        data = null;
      });
    } finally {
      await _refreshOfflineState();
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<({double lat, double lng, double accuracyM})> _resolveLocation() async {
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
    return (lat: pos.latitude, lng: pos.longitude, accuracyM: pos.accuracy);
  }

  Future<String?> _promptExceptionReason() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final controller = TextEditingController();
        bool isSubmitting = false;
        String? localError;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Exception reason", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                  const SizedBox(height: 8),
                  const Text(
                    "You are outside assigned project radius. Please enter reason.",
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: "Reason (required)"),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.danger.withAlpha(40)),
                      ),
                      child: Text(localError!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: isSubmitting ? "Submitting..." : "Submit",
                    icon: Icons.warning_amber_rounded,
                    isLoading: isSubmitting,
                    onPressed: () {
                      final v = controller.text.trim();
                      if (v.isEmpty) {
                        setModalState(() => localError = "Reason is required");
                        return;
                      }
                      setModalState(() {
                        isSubmitting = true;
                        localError = null;
                      });
                      Navigator.of(ctx).pop(v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(null),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _punchIn() async {
    if (isPunchingIn || isPunchingOut) return;
    setState(() {
      isPunchingIn = true;
      actionError = null;
    });
    try {
      final loc = await _resolveLocation();
      final clientPunchId = _uuidV4();
      final clientPunchTimeIso = DateTime.now().toUtc().toIso8601String();
      PunchInResponse resp;
      try {
        resp = await AssignmentService().punchIn(
          token: widget.sessionToken,
          lat: loc.lat,
          lng: loc.lng,
          accuracyM: loc.accuracyM,
          projectId: selectedProjectId,
          clientPunchId: clientPunchId,
          clientPunchTimeIso: clientPunchTimeIso,
          isOffline: false,
        );
      } on ApiException catch (e) {
        if (e.code == "OUT_OF_RADIUS_REASON_REQUIRED") {
          final reason = await _promptExceptionReason();
          if (reason == null) return;
          resp = await AssignmentService().punchIn(
            token: widget.sessionToken,
            lat: loc.lat,
            lng: loc.lng,
            accuracyM: loc.accuracyM,
            exceptionReason: reason,
            projectId: selectedProjectId,
            clientPunchId: clientPunchId,
            clientPunchTimeIso: clientPunchTimeIso,
            isOffline: false,
          );
        } else if (e.statusCode == null) {
          final a = _selectedAssignment();
          if (a == null) {
            throw "Assignment not available for offline punch";
          }
          final distanceM = _haversineDistanceM(
            lat1: loc.lat,
            lng1: loc.lng,
            lat2: a.latitude,
            lng2: a.longitude,
          );
          String? reason;
          if (distanceM > a.allowedRadiusM.toDouble()) {
            reason = await _promptExceptionReason();
            if (reason == null) return;
          }
          final cleanedReason = (reason ?? "").trim();
          await _offlineQueue.add(
            OfflinePunch(
              clientPunchId: clientPunchId,
              type: OfflinePunchType.inPunch,
              clientPunchTimeIso: clientPunchTimeIso,
              lat: loc.lat,
              lng: loc.lng,
              accuracyM: loc.accuracyM,
              projectId: selectedProjectId,
              exceptionReason: cleanedReason.isEmpty ? null : cleanedReason,
            ),
          );
          await _refreshOfflineState();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved offline. Will sync automatically when online.")));
          return;
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      final isException = (resp.isExceptionPunch ?? false) || ((resp.exceptionStatus ?? "").toUpperCase() == "PENDING");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isException ? "Punch submitted for approval" : "Punch Successful")));
      await _load();
    } catch (e) {
      setState(() {
        actionError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isPunchingIn = false;
        });
      }
    }
  }

  Future<void> _punchOut() async {
    if (isPunchingIn || isPunchingOut) return;
    final remarks = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final controller = TextEditingController();
        bool isSubmitting = false;
        String? localError;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Punch out", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                  const SizedBox(height: 8),
                  const Text("Add a short note before punching out.", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: "Remarks (required)"),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.danger.withAlpha(40)),
                      ),
                      child: Text(localError!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: isSubmitting ? "Punching out..." : "Confirm Punch Out",
                    icon: Icons.logout,
                    isLoading: isSubmitting,
                    onPressed: () {
                      final v = controller.text.trim();
                      if (v.isEmpty) {
                        setModalState(() => localError = "Remarks are required");
                        return;
                      }
                      setModalState(() {
                        isSubmitting = true;
                        localError = null;
                      });
                      Navigator.of(ctx).pop(v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(null),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (remarks == null) return;

    setState(() {
      isPunchingOut = true;
      actionError = null;
    });
    try {
      final loc = await _resolveLocation();
      final clientPunchId = _uuidV4();
      final clientPunchTimeIso = DateTime.now().toUtc().toIso8601String();
      PunchOutResponse resp;
      try {
        resp = await AssignmentService().punchOut(
          token: widget.sessionToken,
          lat: loc.lat,
          lng: loc.lng,
          accuracyM: loc.accuracyM,
          remarks: remarks,
          clientPunchId: clientPunchId,
          clientPunchTimeIso: clientPunchTimeIso,
          isOffline: false,
        );
      } on ApiException catch (e) {
        if (e.code == "OUT_OF_RADIUS_REASON_REQUIRED") {
          final reason = await _promptExceptionReason();
          if (reason == null) return;
          resp = await AssignmentService().punchOut(
            token: widget.sessionToken,
            lat: loc.lat,
            lng: loc.lng,
            accuracyM: loc.accuracyM,
            exceptionReason: reason,
            remarks: remarks,
            clientPunchId: clientPunchId,
            clientPunchTimeIso: clientPunchTimeIso,
            isOffline: false,
          );
        } else if (e.statusCode == null) {
          if (!(data?.activeAttendanceLogId ?? "").trim().isNotEmpty && !pendingOfflineIn) {
            throw "No active punch-in found for offline punch-out";
          }
          final a = _selectedAssignment();
          if (a == null) {
            throw "Assignment not available for offline punch";
          }
          final distanceM = _haversineDistanceM(
            lat1: loc.lat,
            lng1: loc.lng,
            lat2: a.latitude,
            lng2: a.longitude,
          );
          String? reason;
          if (distanceM > a.allowedRadiusM.toDouble()) {
            reason = await _promptExceptionReason();
            if (reason == null) return;
          }
          final cleanedReason = (reason ?? "").trim();
          await _offlineQueue.add(
            OfflinePunch(
              clientPunchId: clientPunchId,
              type: OfflinePunchType.outPunch,
              clientPunchTimeIso: clientPunchTimeIso,
              lat: loc.lat,
              lng: loc.lng,
              accuracyM: loc.accuracyM,
              remarks: remarks,
              exceptionReason: cleanedReason.isEmpty ? null : cleanedReason,
            ),
          );
          await _refreshOfflineState();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved offline. Will sync automatically when online.")));
          return;
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      final isException = (resp.isExceptionPunch ?? false) || ((resp.exceptionStatus ?? "").toUpperCase() == "PENDING");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isException ? "Punch submitted for approval" : "Punch Successful")));
      await _load();
    } catch (e) {
      setState(() {
        actionError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isPunchingOut = false;
        });
      }
    }
  }

  TodayAssignment? _selectedAssignment() {
    final resp = data;
    final assignments = resp?.assignments ?? <TodayAssignment>[];
    if (assignments.isEmpty) return null;
    final pid = (selectedProjectId ?? "").trim();
    if (pid.isNotEmpty) {
      return assignments.firstWhere((a) => a.projectId == pid, orElse: () => assignments.first);
    }
    return assignments.first;
  }

  String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int v) => v.toRadixString(16).padLeft(2, "0");
    final b = bytes.map(hex).toList();
    return "${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}";
  }

  double _haversineDistanceM({required double lat1, required double lng1, required double lat2, required double lng2}) {
    const r = 6371000.0;
    double rad(double d) => d * pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  String _dayDateTitle() {
    const weekdays = <String>["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    const months = <String>["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final now = IstTime.now();
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return "$weekday, ${now.day.toString().padLeft(2, "0")} $month ${now.year}";
  }

  @override
  Widget build(BuildContext context) {
    final resp = data;
    final assignments = resp?.assignments ?? <TodayAssignment>[];
    final hasAssignment = resp?.hasAssignment ?? false;
    final TodayAssignment? assignment;
    if (assignments.isEmpty) {
      assignment = null;
    } else if (selectedProjectId != null && selectedProjectId!.trim().isNotEmpty) {
      assignment = assignments.firstWhere((a) => a.projectId == selectedProjectId, orElse: () => assignments.first);
    } else {
      assignment = assignments.first;
    }
    final cs = Theme.of(context).colorScheme;
    final isPunchedInServer = (resp?.activeAttendanceLogId ?? "").trim().isNotEmpty;
    final isPunchedIn = isPunchedInServer || pendingOfflineIn;
    final selectedStatusRaw = (assignment?.todayStatus ?? "").trim();
    final canPunchIn = !isPunchedIn && selectedStatusRaw.isEmpty;
    final canPunchOut = isPunchedIn && !pendingOfflineOut;
    final clientNameRaw = (assignment?.clientName ?? "").trim();
    final addressRaw = (assignment?.address ?? "").trim();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_dayDateTitle()),
        actions: [
          if (pendingOfflineCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: StatusChip(
                  label: "Sync $pendingOfflineCount",
                  color: cs.tertiaryContainer,
                ),
              ),
            ),
          IconButton(
            onPressed: isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                "Hello ${widget.engineerName}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              const Text(
                "Here is your assignment for the day.",
                style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (isLoading) ...[
                const ShimmerBox(width: double.infinity, height: 180, borderRadius: 24),
                const SizedBox(height: 16),
                const ShimmerBox(width: double.infinity, height: 100, borderRadius: 24),
              ],
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(20),
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
                        "Failed to load assignment",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      PrimaryButton(label: "Retry", onPressed: _load, icon: Icons.refresh),
                    ],
                  ),
                ),
              ] else if (!isLoading && (!hasAssignment || assignment == null)) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.softShadow,
                    border: Border.all(color: AppTheme.navy.withAlpha(8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.event_busy_outlined, color: AppTheme.muted, size: 32),
                      const SizedBox(height: 16),
                      const Text(
                        "No assignment for today",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data?.message ?? "You don’t have an active assignment for today.",
                        style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ] else if (!isLoading && assignment != null) ...[
                Row(
                  children: [
                    const Expanded(child: SectionHeader(title: "Assignment Details")),
                  ],
                ),
                const SizedBox(height: 14),
                if (assignments.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: AppTheme.navy.withAlpha(8)),
                    ),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: (selectedProjectId != null && assignments.any((a) => a.projectId == selectedProjectId)) ? selectedProjectId : null,
                      items: assignments
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.projectId,
                              child: Text("${a.projectName} • ${a.siteName}", overflow: TextOverflow.ellipsis),
                            ),
                          )
                            .toList(),
                        onChanged: isPunchedIn
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => selectedProjectId = v);
                              },
                        decoration: const InputDecoration(
                          labelText: "Select Assignment",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.softShadow,
                    border: Border.all(color: AppTheme.navy.withAlpha(8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined, size: 20, color: AppTheme.sky),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              assignment.projectName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _AssignmentDetailRow(label: "Site", value: assignment.siteName),
                      const SizedBox(height: 12),
                      _AssignmentDetailRow(label: "Client", value: clientNameRaw.isEmpty ? "-" : clientNameRaw),
                      const SizedBox(height: 12),
                      _AssignmentDetailRow(label: "Address", value: addressRaw.isEmpty ? "-" : addressRaw),
                      const SizedBox(height: 12),
                      _AssignmentDetailRow(label: "Pending sync", value: "$pendingOfflineCount"),
                      const SizedBox(height: 18),
                      Text(
                        isPunchedIn
                            ? "Punch out when you’re finished."
                            : (selectedStatusRaw == "COMPLETED"
                                ? "Already completed for this assignment today. Select a different assignment to punch in."
                                : "Punch in when you arrive at the site."),
                        style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: "Punch In",
                              isLoading: isPunchingIn,
                              onPressed: (!canPunchIn || isPunchingOut) ? null : _punchIn,
                              icon: Icons.login,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: "Punch Out",
                              isLoading: isPunchingOut,
                              onPressed: (!canPunchOut || isPunchingIn) ? null : _punchOut,
                              icon: Icons.logout,
                            ),
                          ),
                        ],
                      ),
                      if (actionError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.danger.withAlpha(40)),
                          ),
                          child: Text(
                            actionError!,
                            style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: "Day Summary"),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.softShadow,
                    border: Border.all(color: AppTheme.navy.withAlpha(8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPunchedIn ? Icons.login : Icons.logout,
                            color: isPunchedIn ? AppTheme.success : AppTheme.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isPunchedIn ? "Currently Punched In" : "Not Punched In",
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.4, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Use work update to submit your progress photo and activity details after work.",
                        style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TimesheetScreen(sessionToken: widget.sessionToken, engineerEmpCode: widget.engineerEmpCode),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_note),
                              label: const Text("Work Update", style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => ActivityTimelineScreen(sessionToken: widget.sessionToken)),
                                );
                              },
                              icon: const Icon(Icons.timeline),
                              label: const Text("Timeline", style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentDetailRow extends StatelessWidget {
  const _AssignmentDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
