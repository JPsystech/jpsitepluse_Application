import "dart:io";

import "package:flutter/material.dart";
import "package:open_filex/open_filex.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "../../theme/app_theme.dart";

import "../../core/ist_time.dart";
import "../../models/today_assignment.dart";
import "../../services/assignment_service.dart";
import "../../widgets/primary_button.dart";
import "../../widgets/section_header.dart";
import "../../widgets/status_chip.dart";
import "../../widgets/image_viewer.dart";


class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key, required this.sessionToken});

  final String sessionToken;

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  bool isLoading = true;
  bool isDownloading = false;
  String? error;
  EngineerHistoryResponse? data;
  String month = "";
  String statusFilter = "ALL";

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
      final resp = await AssignmentService().history(token: widget.sessionToken, month: month.trim().isEmpty ? null : month);
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

  List<String> _monthOptions() {
    final now = IstTime.now();
    final out = <String>[""];
    for (var i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      out.add("${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}");
    }
    return out;
  }

  String _monthLabel(String value) => value.trim().isEmpty ? "All months" : value;

  Future<void> _openFilters() async {
    String draftMonth = month;
    String draftStatus = statusFilter;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Timeline Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: draftMonth,
                      decoration: const InputDecoration(labelText: "Month", border: OutlineInputBorder()),
                      items: _monthOptions()
                          .map((m) => DropdownMenuItem<String>(value: m, child: Text(_monthLabel(m))))
                          .toList(growable: false),
                      onChanged: (v) => setModalState(() => draftMonth = v ?? ""),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: draftStatus,
                      decoration: const InputDecoration(labelText: "Status", border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: "ALL", child: Text("All status")),
                        DropdownMenuItem(value: "PUNCHED_IN", child: Text("Punched In")),
                        DropdownMenuItem(value: "PUNCHED_OUT", child: Text("Punched Out")),
                        DropdownMenuItem(value: "COMPLETED", child: Text("Completed")),
                      ],
                      onChanged: (v) => setModalState(() => draftStatus = v ?? "ALL"),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              draftMonth = "";
                              draftStatus = "ALL";
                              Navigator.of(ctx).pop(true);
                            },
                            child: const Text("Clear"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (applied != true) return;
    setState(() {
      month = draftMonth;
      statusFilter = draftStatus;
    });
    await _load();
  }

  List<EngineerHistoryRow> _filteredItems(List<EngineerHistoryRow> items) {
    if (statusFilter == "ALL") return items;
    return items.where((item) => item.status.trim().toUpperCase() == statusFilter).toList();
  }

  Future<void> _downloadTimelinePdf() async {
    if (isDownloading) return;
    setState(() {
      isDownloading = true;
    });
    try {
      final resp = await AssignmentService().timesheetsPdf(
        token: widget.sessionToken,
        month: month.trim().isEmpty ? null : month,
      );
      final dir = await getApplicationDocumentsDirectory();
      final safeName = resp.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
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
                  const Text("Timeline PDF saved", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
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
                      await Share.shareXFiles([XFile(file.path)], text: "My timeline PDF");
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }

  String _fmtDate(String s) {
    if (s.trim().length >= 10) return s.trim().substring(0, 10);
    return s;
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return "-";
    return IstTime.formatTime(dt);
  }

  bool _isSystemAutoClosed(String? remarks) {
    return (remarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");
  }

  String _displayRemarks(String? remarks) {
    final raw = (remarks ?? "").trim();
    if (raw.isEmpty) return "";
    if (_isSystemAutoClosed(raw)) return "Closed by system";
    return raw;
  }

  Color _chipColor(ColorScheme cs, String status) {
    final s = status.trim().toUpperCase();
    if (s == "COMPLETED" || s == "PUNCHED_OUT") return AppTheme.successBg;
    if (s == "PUNCHED_IN") return AppTheme.sky.withAlpha(26);
    return cs.primaryContainer;
  }

  Widget _thumb(BuildContext context, String url) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewer(url: url),
            fullscreenDialog: true,
          ),
        );
      },
      child: Hero(
        tag: url,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 84,
              height: 84,
              color: AppTheme.bg,
              child: const Icon(Icons.broken_image_outlined, color: AppTheme.muted),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 84,
                height: 84,
                color: AppTheme.bg,
                child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            },
          ),
        ),
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
            Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800))),
            Text("${urls.length}", style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) => _thumb(ctx, shown[idx]),

          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _filteredItems(data?.items ?? const <EngineerHistoryRow>[]);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Timeline"),
        actions: [
          IconButton(onPressed: isLoading ? null : _openFilters, icon: const Icon(Icons.filter_alt_outlined)),
          IconButton(onPressed: isDownloading ? null : _downloadTimelinePdf, icon: const Icon(Icons.download_outlined)),
          IconButton(onPressed: isLoading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionHeader(title: "Activity Timeline")),
                  if (month.trim().isNotEmpty)
                    StatusChip(label: _monthLabel(month), color: cs.primaryContainer),
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
                        const Text("Failed to load timeline", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                        const SizedBox(height: 8),
                        Text(error!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        PrimaryButton(label: "Retry", onPressed: _load, icon: Icons.refresh),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ] else if (!isLoading && items.isEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("No activity yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                        SizedBox(height: 8),
                        Text("Punch in/out and submit work updates to build your timeline.", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ] else ...[
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final row = items[idx];
                      final chip = _chipColor(cs, row.status);
                      final isAutoClosed = _isSystemAutoClosed(row.remarks);
                      return Card(
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
                                  if (row.status.trim().isNotEmpty) StatusChip(label: row.status, color: chip),
                                  if (isAutoClosed) ...[
                                    const SizedBox(width: 8),
                                    const StatusChip(label: "AUTO CLOSED", color: AppTheme.warningBg),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
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
                                        const Text("Punch In", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTime(row.punchInTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Punch Out", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(_fmtTime(row.punchOutTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_displayRemarks(row.remarks).isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text("Punch-out remarks", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(_displayRemarks(row.remarks), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                              _photoRow("Punch-in photos", row.punchInPhotoUrls),
                              _photoRow("Punch-out photos", row.punchOutPhotoUrls),
                              _photoRow("Work updates", row.progressPhotoUrls),
                            ],
                          ),
                        ),
                      );
                    },
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
