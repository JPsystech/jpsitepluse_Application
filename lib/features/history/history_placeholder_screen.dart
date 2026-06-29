import "dart:io";

import "package:flutter/material.dart";
import "package:open_filex/open_filex.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "../../core/ist_time.dart";
import "../../models/today_assignment.dart";
import "../../services/assignment_service.dart";
import "../../widgets/primary_button.dart";
import "../../widgets/section_header.dart";
import "../../widgets/status_chip.dart";
import "../../widgets/shimmer_box.dart";
import "../../theme/app_theme.dart";

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.sessionToken});

  final String sessionToken;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool isLoading = true;
  bool isOptionsLoading = true;
  bool isExporting = false;
  String? error;
  EngineerTimesheetListResponse? data;

  late String month;
  late final TextEditingController startDateCtrl;
  late final TextEditingController endDateCtrl;
  String? selectedClient;
  String? selectedProject;
  String? selectedSite;
  List<String> clientOptions = const <String>[];
  List<String> projectOptions = const <String>[];
  List<String> siteOptions = const <String>[];

  @override
  void initState() {
    super.initState();
    final now = IstTime.now();
    month = "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
    startDateCtrl = TextEditingController(text: "");
    endDateCtrl = TextEditingController(text: "");
    _initLoad();
  }

  @override
  void dispose() {
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    await _loadFilterOptions();
    await _load();
  }

  Future<void> _loadFilterOptions() async {
    setState(() {
      isOptionsLoading = true;
    });
    try {
      final useMonth = month.trim().isNotEmpty;
      final resp = await AssignmentService().timesheetFilterOptions(
        token: widget.sessionToken,
        month: useMonth ? month : null,
        startDate: useMonth ? null : startDateCtrl.text,
        endDate: useMonth ? null : endDateCtrl.text,
        client: selectedClient,
        project: selectedProject,
      );

      String? nextClient = selectedClient;
      if (nextClient != null && !resp.clients.contains(nextClient)) nextClient = null;
      if (nextClient == null && resp.clients.length == 1) nextClient = resp.clients.first;

      String? nextProject = selectedProject;
      if (nextProject != null && !resp.projects.contains(nextProject)) nextProject = null;
      if (nextProject == null && resp.projects.length == 1) nextProject = resp.projects.first;

      String? nextSite = selectedSite;
      if (nextSite != null && !resp.sites.contains(nextSite)) nextSite = null;
      if (nextSite == null && resp.sites.length == 1) nextSite = resp.sites.first;

      setState(() {
        clientOptions = resp.clients;
        projectOptions = resp.projects;
        siteOptions = resp.sites;
        selectedClient = nextClient;
        selectedProject = nextProject;
        selectedSite = nextSite;
      });
    } catch (e) {
      setState(() {
        clientOptions = const <String>[];
        projectOptions = const <String>[];
        siteOptions = const <String>[];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load filters: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() {
          isOptionsLoading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final resp = await AssignmentService().timesheets(
        token: widget.sessionToken,
        month: month,
        startDate: month.trim().isNotEmpty ? null : startDateCtrl.text,
        endDate: month.trim().isNotEmpty ? null : endDateCtrl.text,
        client: selectedClient,
        project: selectedProject,
        site: selectedSite,
        limit: 366,
      );
      setState(() {
        data = resp;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        data = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf({required bool filtered}) async {
    if (isExporting) return;
    setState(() {
      isExporting = true;
    });
    try {
      final useMonth = month.trim().isNotEmpty;
      final resp = await AssignmentService().timesheetsPdf(
        token: widget.sessionToken,
        month: useMonth ? month : null,
        startDate: useMonth ? null : startDateCtrl.text,
        endDate: useMonth ? null : endDateCtrl.text,
        client: filtered ? selectedClient : null,
        project: filtered ? selectedProject : null,
        site: filtered ? selectedSite : null,
      );

      final dir = await getApplicationDocumentsDirectory();
      final safeName = resp.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File("${dir.path}/$safeName");
      await file.writeAsBytes(resp.bytes, flush: true);

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Timesheet PDF saved", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                  const SizedBox(height: 6),
                  Text(safeName, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: "Open PDF",
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await OpenFilex.open(file.path);
                    },
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: "Share PDF",
                    icon: Icons.share_outlined,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await Share.shareXFiles([XFile(file.path)], text: "My Timesheet PDF");
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Close")),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    if (isExporting) return;
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Download Timesheet PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text("Export All", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.filter_alt_outlined, size: 18),
                    label: const Text("Export Filtered", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    await _downloadPdf(filtered: selected);
  }

  String _fmtDate(String s) {
    if (s.trim().length >= 10) return s.trim().substring(0, 10);
    return s;
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return "-";
    return IstTime.formatTime(dt);
  }

  String _fmtHours(double v) {
    if (v <= 0) return "0";
    final s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r"\.?0+$"), "");
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = IstTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    final v = "${picked.year.toString().padLeft(4, "0")}-${picked.month.toString().padLeft(2, "0")}-${picked.day.toString().padLeft(2, "0")}";
    setState(() {
      if (isStart) {
        startDateCtrl.text = v;
      } else {
        endDateCtrl.text = v;
      }
      month = "";
    });
    await _loadFilterOptions();
  }

  List<String> _monthOptions() {
    final now = IstTime.now();
    final out = <String>[];
    for (var i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      out.add("${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}");
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = data?.items ?? const <EngineerTimesheetRow>[];
    final summary = data;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text("My Timesheet")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
              Row(
                children: [
                  const Expanded(child: SectionHeader(title: "My Timesheet")),
                  IconButton(onPressed: isLoading ? null : _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Filters", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: month.trim().isEmpty ? null : month,
                              decoration: const InputDecoration(isDense: true, labelText: "Month", border: OutlineInputBorder()),
                              items: _monthOptions().map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(growable: false),
                              onChanged: isOptionsLoading
                                  ? null
                                  : (v) {
                                      setState(() {
                                        month = v ?? "";
                                        startDateCtrl.text = "";
                                        endDateCtrl.text = "";
                                        selectedProject = null;
                                        selectedSite = null;
                                      });
                                      _loadFilterOptions();
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(isDense: true, labelText: "Start date", border: OutlineInputBorder()),
                              controller: startDateCtrl,
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(isDense: true, labelText: "End date", border: OutlineInputBorder()),
                              controller: endDateCtrl,
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClient,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true, labelText: "Client", border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: SizedBox(width: double.infinity, child: Text("All", maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ),
                                ...clientOptions.map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: SizedBox(width: double.infinity, child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              ],
                              selectedItemBuilder: (context) => [
                                const Text("All", maxLines: 1, overflow: TextOverflow.ellipsis),
                                ...clientOptions.map((c) => Text(c, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isOptionsLoading
                                  ? null
                                  : (v) {
                                      setState(() {
                                        selectedClient = v;
                                        selectedProject = null;
                                        selectedSite = null;
                                      });
                                      _loadFilterOptions();
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedProject,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true, labelText: "Project", border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: SizedBox(width: double.infinity, child: Text("All", maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ),
                                ...projectOptions.map(
                                  (p) => DropdownMenuItem<String>(
                                    value: p,
                                    child: SizedBox(width: double.infinity, child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              ],
                              selectedItemBuilder: (context) => [
                                const Text("All", maxLines: 1, overflow: TextOverflow.ellipsis),
                                ...projectOptions.map((p) => Text(p, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isOptionsLoading
                                  ? null
                                  : (v) {
                                      setState(() {
                                        selectedProject = v;
                                        selectedSite = null;
                                      });
                                      _loadFilterOptions();
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSite,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true, labelText: "Site", border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: SizedBox(width: double.infinity, child: Text("All", maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ),
                                ...siteOptions.map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: SizedBox(width: double.infinity, child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              ],
                              selectedItemBuilder: (context) => [
                                const Text("All", maxLines: 1, overflow: TextOverflow.ellipsis),
                                ...siteOptions.map((s) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isOptionsLoading ? null : (v) => setState(() => selectedSite = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: "Apply",
                              onPressed: isLoading || isOptionsLoading ? null : _load,
                              icon: Icons.filter_alt_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        final now = IstTime.now();
                                        setState(() {
                                          month = "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
                                          startDateCtrl.text = "";
                                          endDateCtrl.text = "";
                                  selectedClient = null;
                                  selectedProject = null;
                                  selectedSite = null;
                                        });
                                _loadFilterOptions();
                                _load();
                                      },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: AppTheme.border),
                                  foregroundColor: AppTheme.navy,
                                ),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text("Reset", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.softShadow,
                    border: Border.all(color: AppTheme.navy.withAlpha(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Present Days", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text("${summary.totalPresentDays}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppTheme.border.withAlpha(100)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total Hours", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_fmtHours(summary.totalHours), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: isExporting ? "Generating PDF..." : "Download Report",
                  onPressed: isLoading || isExporting ? null : _exportPdf,
                  icon: Icons.file_download_outlined,
                  isLoading: isExporting,
                ),
              ],
              if (isLoading) ...[
                const SizedBox(height: 16),
                const ShimmerBox(width: double.infinity, height: 100, borderRadius: 24),
                const SizedBox(height: 16),
                const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
                const SizedBox(height: 16),
                const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
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
                      const Text("Failed to load records", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      PrimaryButton(label: "Retry", onPressed: _load, icon: Icons.refresh),
                    ],
                  ),
                ),
              ] else if (!isLoading && items.isEmpty) ...[
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
                    children: const [
                      Icon(Icons.history_rounded, color: AppTheme.muted, size: 32),
                      const SizedBox(height: 16),
                      Text("No records found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 8),
                      Text("Your timesheet records will appear here once you punch in/out.", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ListView.separated(
                  itemCount: items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final row = items[idx];
                    final mark = (row.mark ?? "").trim().isEmpty ? "-" : row.mark!.trim();
                    final markColor = mark == "P" ? AppTheme.successBg : cs.primaryContainer;
                    final isAutoClosed = (row.remarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");
                    return Card(
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TimesheetDetailScreen(
                                sessionToken: widget.sessionToken,
                                attendanceLogId: row.attendanceLogId,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fmtDate(row.workDate),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                                    ),
                                  ),
                                  StatusChip(label: mark, color: markColor),
                                  if (isAutoClosed) ...[
                                    const SizedBox(width: 8),
                                    const StatusChip(label: "AUTO CLOSED", color: AppTheme.warningBg),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              if ((row.clientName ?? "").trim().isNotEmpty) ...[
                                Text(row.clientName!.trim(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                              ],
                              Text(row.projectName, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                              const SizedBox(height: 4),
                              Text(row.siteName, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Punch In", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTime(row.punchInTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Punch Out", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTime(row.punchOutTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Hours", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(_fmtHours(row.totalHours), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if ((row.remarks ?? "").trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text("Remark", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  isAutoClosed ? "Closed by system" : row.remarks!.trim(),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                              const SizedBox(height: 6),
                              const Text("Tap to view details", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
  }
}

class TimesheetDetailScreen extends StatefulWidget {
  const TimesheetDetailScreen({super.key, required this.sessionToken, required this.attendanceLogId});

  final String sessionToken;
  final String attendanceLogId;

  @override
  State<TimesheetDetailScreen> createState() => _TimesheetDetailScreenState();
}

class _TimesheetDetailScreenState extends State<TimesheetDetailScreen> {
  bool isLoading = true;
  String? error;
  EngineerTimesheetDetailResponse? data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final resp = await AssignmentService()
          .timesheetDetailByLog(token: widget.sessionToken, attendanceLogId: widget.attendanceLogId);
      setState(() {
        data = resp;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        data = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return "-";
    return IstTime.formatTime(dt);
  }

  String _fmtHours(double v) {
    if (v <= 0) return "0";
    final s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r"\.?0+$"), "");
  }

  Color _chipColor(ColorScheme cs, String label) {
    final v = label.trim().toUpperCase();
    if (v == "P") return AppTheme.successBg;
    if (v == "PUNCHED_IN") return AppTheme.sky.withAlpha(26);
    if (v == "PUNCHED_OUT") return AppTheme.successBg;
    return cs.primaryContainer;
  }

  Widget _thumb(String url) {
    final v = url.trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        v,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: 84,
          height: 84,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 84,
            height: 84,
            color: const Color(0xFFF1F5F9),
            child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        },
      ),
    );
  }

  Widget _photoRow(String label, List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final shown = urls.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800))),
            Text("${urls.length}", style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, idx) => _thumb(shown[idx]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = data;
    final isAutoClosed = (d?.punchOutRemarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");

    return Scaffold(
      appBar: AppBar(title: const Text("Timesheet Detail")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SectionHeader(title: widget.attendanceLogId)),
                  IconButton(onPressed: isLoading ? null : _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading) const LinearProgressIndicator(),
              if (error != null) ...[
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Failed to load detail", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                        const SizedBox(height: 8),
                        Text(error!, style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        PrimaryButton(label: "Retry", onPressed: _load, icon: Icons.refresh),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ] else if (!isLoading && d != null) ...[
                Expanded(
                  child: ListView(
                    children: [
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
                                        if ((d.clientName ?? "").trim().isNotEmpty)
                                          Text(d.clientName!.trim(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        Text(
                                          d.projectName,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(d.siteName, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                        if ((d.address ?? "").trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(d.address!.trim(), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if ((d.mark ?? "").trim().isNotEmpty) StatusChip(label: d.mark!.trim(), color: _chipColor(cs, d.mark!)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Status", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(d.status, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Total Hours", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(_fmtHours(d.totalHours), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Punch In", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTime(d.punchInTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Punch Out", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTime(d.punchOutTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if ((d.punchOutRemarks ?? "").trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: const [
                                    Expanded(
                                      child: Text("Work Remark", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                                if (isAutoClosed) ...[
                                  const SizedBox(height: 8),
                                  const StatusChip(label: "AUTO CLOSED", color: Color(0xFFFFF3C4)),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  isAutoClosed ? "Closed by system" : d.punchOutRemarks!.trim(),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                              _photoRow("Punch-in photos", d.punchInPhotoUrls),
                              _photoRow("Punch-out photos", d.punchOutPhotoUrls),
                              _photoRow("Progress photos", d.progressPhotoUrls),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
