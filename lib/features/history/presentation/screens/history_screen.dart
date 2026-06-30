import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sitepulse_engineer/core/theme/app_theme.dart';
import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/core/utils/formatters.dart';
import 'package:sitepulse_engineer/shared/models/today_assignment.dart';
import 'package:sitepulse_engineer/shared/widgets/primary_button.dart';
import 'package:sitepulse_engineer/shared/widgets/section_header.dart';
import 'package:sitepulse_engineer/shared/widgets/status_chip.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';
import 'package:sitepulse_engineer/features/history/presentation/bloc/history_bloc.dart';
import 'package:sitepulse_engineer/features/history/presentation/screens/history_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.sessionToken});

  final String sessionToken;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final now = IstTime.now();
        final month = "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
        return HistoryBloc()
          ..add(LoadHistoryFiltersRequested(sessionToken: sessionToken, month: month))
          ..add(LoadHistoryRequested(sessionToken: sessionToken, month: month));
      },
      child: _HistoryView(sessionToken: sessionToken),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView({required this.sessionToken});

  final String sessionToken;

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  late String month;
  late final TextEditingController startDateCtrl;
  late final TextEditingController endDateCtrl;
  String? selectedClient;
  String? selectedProject;
  String? selectedSite;

  @override
  void initState() {
    super.initState();
    final now = IstTime.now();
    month = "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
    startDateCtrl = TextEditingController(text: "");
    endDateCtrl = TextEditingController(text: "");
  }

  @override
  void dispose() {
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    super.dispose();
  }

  void _loadFilterOptions() {
    context.read<HistoryBloc>().add(LoadHistoryFiltersRequested(
          sessionToken: widget.sessionToken,
          month: month,
          startDate: month.trim().isNotEmpty ? null : startDateCtrl.text,
          endDate: month.trim().isNotEmpty ? null : endDateCtrl.text,
          selectedClient: selectedClient,
          selectedProject: selectedProject,
        ));
  }

  void _load() {
    context.read<HistoryBloc>().add(LoadHistoryRequested(
          sessionToken: widget.sessionToken,
          month: month,
          startDate: month.trim().isNotEmpty ? null : startDateCtrl.text,
          endDate: month.trim().isNotEmpty ? null : endDateCtrl.text,
          selectedClient: selectedClient,
          selectedProject: selectedProject,
          selectedSite: selectedSite,
        ));
  }

  void _downloadPdf({required bool filtered}) {
    context.read<HistoryBloc>().add(DownloadHistoryPdfRequested(
          sessionToken: widget.sessionToken,
          month: month,
          startDate: month.trim().isNotEmpty ? null : startDateCtrl.text,
          endDate: month.trim().isNotEmpty ? null : endDateCtrl.text,
          selectedClient: filtered ? selectedClient : null,
          selectedProject: filtered ? selectedProject : null,
          selectedSite: filtered ? selectedSite : null,
        ));
  }

  Future<void> _exportPdf() async {
    final state = context.read<HistoryBloc>().state;
    if (state.status == HistoryStatus.downloading) return;

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
    _downloadPdf(filtered: selected);
  }

  void _showPdfBottomSheet(String fileName, String filePath) {
    showModalBottomSheet<void>(
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
                Text(fileName, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: "Open PDF",
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await OpenFilex.open(filePath);
                  },
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: "Share PDF",
                  icon: Icons.share_outlined,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Share.shareXFiles([XFile(filePath)], text: "My Timesheet PDF");
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
    _loadFilterOptions();
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

    return BlocConsumer<HistoryBloc, HistoryState>(
      listener: (context, state) {
        if (state.status == HistoryStatus.downloadSuccess) {
          if (state.downloadedFileName != null && state.downloadedFilePath != null) {
            _showPdfBottomSheet(state.downloadedFileName!, state.downloadedFilePath!);
          }
        } else if (state.status == HistoryStatus.downloadError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage)));
        } else if (state.status == HistoryStatus.filtersError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load filters: ${state.errorMessage}")));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == HistoryStatus.loading || state.status == HistoryStatus.initial;
        final isOptionsLoading = state.status == HistoryStatus.filtersLoading;
        final isExporting = state.status == HistoryStatus.downloading;
        final data = state.data;
        final items = data?.items ?? const <EngineerTimesheetRow>[];
        final error = state.status == HistoryStatus.error ? state.errorMessage : null;
        
        final clientOptions = state.clientOptions;
        final projectOptions = state.projectOptions;
        final siteOptions = state.siteOptions;
        
        if (!clientOptions.contains(selectedClient)) selectedClient = null;
        if (selectedClient == null && clientOptions.length == 1) selectedClient = clientOptions.first;

        if (!projectOptions.contains(selectedProject)) selectedProject = null;
        if (selectedProject == null && projectOptions.length == 1) selectedProject = projectOptions.first;

        if (!siteOptions.contains(selectedSite)) selectedSite = null;
        if (selectedSite == null && siteOptions.length == 1) selectedSite = siteOptions.first;

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
                if (data != null) ...[
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
                              Text("${data.totalPresentDays}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
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
                              Text(AppFormatters.formatHours(data.totalHours), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
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
                        Text(error, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
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
                        SizedBox(height: 16),
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
                                builder: (_) => HistoryDetailScreen(
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
                                        AppFormatters.formatDateString(row.workDate),
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
                                          Text(AppFormatters.formatTime(row.punchInTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Punch Out", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text(AppFormatters.formatTime(row.punchOutTime), style: const TextStyle(fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Hours", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text(AppFormatters.formatHours(row.totalHours), style: const TextStyle(fontWeight: FontWeight.w900)),
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
      },
    );
  }
}
