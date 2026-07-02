import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
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
        final month =
            "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
        return HistoryBloc()
          ..add(LoadHistoryFiltersRequested(
              sessionToken: sessionToken, month: month))
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
    month =
        "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
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
                const Text("Download Timesheet PDF",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text("Export All",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.filter_alt_outlined, size: 18),
                    label: const Text("Export Filtered",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
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
                const Text("Timesheet PDF saved",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2)),
                const SizedBox(height: 6),
                Text(fileName,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700)),
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
                    await Share.shareXFiles([XFile(filePath)],
                        text: "My Timesheet PDF");
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Close")),
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
    final v =
        "${picked.year.toString().padLeft(4, "0")}-${picked.month.toString().padLeft(2, "0")}-${picked.day.toString().padLeft(2, "0")}";
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
      out.add(
          "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}");
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.onSurface.withAlpha(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary.withAlpha(100), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return BlocConsumer<HistoryBloc, HistoryState>(
      listener: (context, state) {
        if (state.status == HistoryStatus.downloadSuccess) {
          if (state.downloadedFileName != null &&
              state.downloadedFilePath != null) {
            _showPdfBottomSheet(
                state.downloadedFileName!, state.downloadedFilePath!);
          }
        } else if (state.status == HistoryStatus.downloadError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.errorMessage)));
        } else if (state.status == HistoryStatus.filtersError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Failed to load filters: ${state.errorMessage}")));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == HistoryStatus.loading ||
            state.status == HistoryStatus.initial;
        final isOptionsLoading = state.status == HistoryStatus.filtersLoading;
        final isExporting = state.status == HistoryStatus.downloading;
        final data = state.data;
        final items = data?.items ?? const <EngineerTimesheetRow>[];
        final error =
            state.status == HistoryStatus.error ? state.errorMessage : null;

        final clientOptions = state.clientOptions;
        final projectOptions = state.projectOptions;
        final siteOptions = state.siteOptions;

        if (!clientOptions.contains(selectedClient)) selectedClient = null;
        if (selectedClient == null && clientOptions.length == 1)
          selectedClient = clientOptions.first;

        if (!projectOptions.contains(selectedProject)) selectedProject = null;
        if (selectedProject == null && projectOptions.length == 1)
          selectedProject = projectOptions.first;

        if (!siteOptions.contains(selectedSite)) selectedSite = null;
        if (selectedSite == null && siteOptions.length == 1)
          selectedSite = siteOptions.first;

        return Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text("My Timesheet")),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text("My Timesheet",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -0.5))),
                    IconButton(
                        onPressed: isLoading ? null : _load,
                        icon: const Icon(Icons.refresh)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: Theme.of(context)
                        .extension<AppColorsExtension>()!
                        .softShadow,
                    border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list_rounded,
                              size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text("Filters",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: -0.2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: month.trim().isEmpty ? null : month,
                              decoration: inputDecoration.copyWith(labelText: "Month"),
                              items: _monthOptions()
                                  .map((m) => DropdownMenuItem<String>(
                                      value: m, child: Text(m)))
                                  .toList(growable: false),
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
                              decoration: inputDecoration.copyWith(labelText: "Start date"),
                              controller: startDateCtrl,
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              decoration: inputDecoration.copyWith(labelText: "End date"),
                              controller: endDateCtrl,
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClient,
                              isExpanded: true,
                              decoration: inputDecoration.copyWith(labelText: "Client"),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: SizedBox(
                                      width: double.infinity,
                                      child: Text("All",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                ),
                                ...clientOptions.map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: SizedBox(
                                        width: double.infinity,
                                        child: Text(c,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              ],
                              selectedItemBuilder: (context) => [
                                const Text("All",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                ...clientOptions.map((c) => Text(c,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedProject,
                              isExpanded: true,
                              decoration: inputDecoration.copyWith(labelText: "Project"),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: SizedBox(
                                      width: double.infinity,
                                      child: Text("All",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                ),
                                ...projectOptions.map(
                                  (p) => DropdownMenuItem<String>(
                                    value: p,
                                    child: SizedBox(
                                        width: double.infinity,
                                        child: Text(p,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              ],
                              selectedItemBuilder: (context) => [
                                const Text("All",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                ...projectOptions.map((p) => Text(p,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
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
                              decoration: inputDecoration.copyWith(labelText: "Site"),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: SizedBox(
                                      width: double.infinity,
                                      child: Text("All",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                ),
                                ...siteOptions.map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: SizedBox(
                                        width: double.infinity,
                                        child: Text(s,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              ],
                              selectedItemBuilder: (context) => [
                                const Text("All",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                ...siteOptions.map((s) => Text(s,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isOptionsLoading
                                  ? null
                                  : (v) => setState(() => selectedSite = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: "Apply",
                              onPressed: isLoading || isOptionsLoading
                                  ? null
                                  : _load,
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
                                          month =
                                              "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}";
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
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface.withAlpha(20), width: 1.5),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text("Reset",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (data != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withAlpha(200),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withAlpha(80),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Present Days",
                                  style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text("${data.totalPresentDays}",
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withAlpha(50)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total Hours",
                                  style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(AppFormatters.formatHours(data.totalHours),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label:
                        isExporting ? "Generating PDF..." : "Download Report",
                    onPressed: isLoading || isExporting ? null : _exportPdf,
                    icon: Icons.file_download_outlined,
                    isLoading: isExporting,
                  ),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const ShimmerBox(
                      width: double.infinity, height: 100, borderRadius: 24),
                  const SizedBox(height: 16),
                  const ShimmerBox(
                      width: double.infinity, height: 120, borderRadius: 24),
                  const SizedBox(height: 16),
                  const ShimmerBox(
                      width: double.infinity, height: 120, borderRadius: 24),
                ],
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: Theme.of(context)
                          .extension<AppColorsExtension>()!
                          .softShadow,
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Failed to load records",
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 10),
                        Text(error,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        PrimaryButton(
                            label: "Retry",
                            onPressed: _load,
                            icon: Icons.refresh),
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
                      boxShadow: Theme.of(context)
                          .extension<AppColorsExtension>()!
                          .softShadow,
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.history_rounded,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 32),
                        SizedBox(height: 16),
                        Text("No records found",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 8),
                        Text(
                            "Your timesheet records will appear here once you punch in/out.",
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
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
                      final mark = (row.mark ?? "").trim().isEmpty
                          ? "-"
                          : row.mark!.trim();
                      final markColor = mark == "P"
                          ? Theme.of(context)
                              .extension<AppColorsExtension>()!
                              .successBg
                          : cs.primaryContainer;
                      final isAutoClosed =
                          (row.remarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: Theme.of(context).extension<AppColorsExtension>()!.softShadow,
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(10)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(width: 6, color: markColor),
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
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
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: -0.2),
                                                  ),
                                                ),
                                                StatusChip(label: mark, color: markColor),
                                                if (isAutoClosed) ...[
                                                  const SizedBox(width: 8),
                                                  StatusChip(
                                                      label: "AUTO CLOSED",
                                                      color: Theme.of(context)
                                                          .extension<AppColorsExtension>()!
                                                          .warningBg),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            if ((row.clientName ?? "").trim().isNotEmpty) ...[
                                              Text(row.clientName!.trim(),
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w800, fontSize: 13)),
                                              const SizedBox(height: 4),
                                            ],
                                            Text(row.projectName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18,
                                                    letterSpacing: -0.2)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(row.siteName,
                                                      style: TextStyle(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight: FontWeight.w600)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text("Punch In",
                                                            style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w800)),
                                                        const SizedBox(height: 4),
                                                        Text(AppFormatters.formatTime(row.punchInTime),
                                                            style: const TextStyle(fontWeight: FontWeight.w900)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text("Punch Out",
                                                            style: TextStyle(
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w800)),
                                                        const SizedBox(height: 4),
                                                        Text(AppFormatters.formatTime(row.punchOutTime),
                                                            style: const TextStyle(fontWeight: FontWeight.w900)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text("Hours",
                                                            style: TextStyle(
                                                                color: Theme.of(context).colorScheme.primary,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w800)),
                                                        const SizedBox(height: 4),
                                                        Text(AppFormatters.formatHours(row.totalHours),
                                                            style: TextStyle(
                                                                color: Theme.of(context).colorScheme.primary,
                                                                fontWeight: FontWeight.w900)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if ((row.remarks ?? "").trim().isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).extension<AppColorsExtension>()!.warningBg.withAlpha(20),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Theme.of(context).extension<AppColorsExtension>()!.warningBg.withAlpha(50)),
                                                ),
                                                child: Text(
                                                  isAutoClosed ? "System auto-closed" : row.remarks!.trim(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
