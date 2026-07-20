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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Export Timesheet",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Choose how you want to export your records.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("Export All Records"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.filter_list_rounded),
                  label: const Text("Export Filtered Only"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      size: 32, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  "Export Successful",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await OpenFilex.open(filePath);
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text("Open PDF"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Share.shareXFiles([XFile(filePath)],
                        text: "My Timesheet PDF");
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text("Share PDF"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
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

    // Modern Enterprise Input Decoration
    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
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
        if (selectedClient == null && clientOptions.length == 1) {
          selectedClient = clientOptions.first;
        }

        if (!projectOptions.contains(selectedProject)) selectedProject = null;
        if (selectedProject == null && projectOptions.length == 1) {
          selectedProject = projectOptions.first;
        }

        if (!siteOptions.contains(selectedSite)) selectedSite = null;
        if (selectedSite == null && siteOptions.length == 1) {
          selectedSite = siteOptions.first;
        }

        return Scaffold(
            backgroundColor: cs.surface,
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  _load();
                  await Future.delayed(const Duration(milliseconds: 600));
                },
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: cs.surface,
                      scrolledUnderElevation: 1,
                      automaticallyImplyLeading: false,
                      title: Row(
                        children: [
                          Icon(Icons.history_rounded, color: cs.primary),
                          const SizedBox(width: 12),
                          Text(
                            "Timesheet History",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      actions: const [],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFilterCard(
                                context,
                                cs,
                                inputDecoration,
                                isLoading,
                                isOptionsLoading,
                                clientOptions,
                                projectOptions,
                                siteOptions),
                            const SizedBox(height: 24),
                            if (data != null) ...[
                              _buildSummaryCard(context, cs, data, isExporting),
                              const SizedBox(height: 24),
                            ],
                            if (isLoading) ...[
                              const ShimmerBox(
                                  width: double.infinity,
                                  height: 120,
                                  borderRadius: 24),
                              const SizedBox(height: 16),
                              const ShimmerBox(
                                  width: double.infinity,
                                  height: 120,
                                  borderRadius: 24),
                              const SizedBox(height: 16),
                              const ShimmerBox(
                                  width: double.infinity,
                                  height: 120,
                                  borderRadius: 24),
                            ],
                            if (error != null)
                              _buildErrorState(context, cs, error)
                            else if (!isLoading && items.isEmpty)
                              _buildEmptyState(context, cs)
                            else if (!isLoading && items.isNotEmpty)
                              _buildHistoryList(context, cs, items),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ));
      },
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, ColorScheme cs, dynamic data, bool isExporting) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              cs.primary.withAlpha(200),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    context,
                    label: "Present Days",
                    value: "${data.totalPresentDays}",
                    icon: Icons.calendar_today_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryMetric(
                    context,
                    label: "Total Hours",
                    value: AppFormatters.formatHours(data.totalHours),
                    icon: Icons.access_time_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonalIcon(
                onPressed: isExporting ? null : _exportPdf,
                icon: isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_download_rounded, size: 20),
                label: Text(
                  isExporting ? "Generating PDF..." : "Export Report",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(BuildContext context,
      {required String label, required String value, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterCard(
      BuildContext context,
      ColorScheme cs,
      InputDecoration inputDecoration,
      bool isLoading,
      bool isOptionsLoading,
      List<String> clientOptions,
      List<String> projectOptions,
      List<String> siteOptions) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  "Filters",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: month.trim().isEmpty ? null : month,
                    decoration: inputDecoration.copyWith(labelText: "Month"),
                    icon: Icon(Icons.arrow_drop_down_rounded,
                        color: cs.onSurfaceVariant),
                    isExpanded: true,
                    items: _monthOptions()
                        .map((m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(m, overflow: TextOverflow.ellipsis)))
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
                    decoration: inputDecoration.copyWith(
                      labelText: "Start date",
                      suffixIcon: Icon(Icons.calendar_today_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                    ),
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
                    decoration: inputDecoration.copyWith(
                      labelText: "End date",
                      suffixIcon: Icon(Icons.calendar_today_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                    ),
                    controller: endDateCtrl,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedClient,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_rounded,
                        color: cs.onSurfaceVariant),
                    decoration: inputDecoration.copyWith(labelText: "Client"),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("All", overflow: TextOverflow.ellipsis),
                      ),
                      ...clientOptions.map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    selectedItemBuilder: (context) => [
                      const Text("All", overflow: TextOverflow.ellipsis),
                      ...clientOptions
                          .map((c) => Text(c, overflow: TextOverflow.ellipsis)),
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
                    icon: Icon(Icons.arrow_drop_down_rounded,
                        color: cs.onSurfaceVariant),
                    decoration: inputDecoration.copyWith(labelText: "Project"),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("All", overflow: TextOverflow.ellipsis),
                      ),
                      ...projectOptions.map((p) => DropdownMenuItem<String>(
                            value: p,
                            child: Text(p, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    selectedItemBuilder: (context) => [
                      const Text("All", overflow: TextOverflow.ellipsis),
                      ...projectOptions
                          .map((p) => Text(p, overflow: TextOverflow.ellipsis)),
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
                    icon: Icon(Icons.arrow_drop_down_rounded,
                        color: cs.onSurfaceVariant),
                    decoration: inputDecoration.copyWith(labelText: "Site"),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("All", overflow: TextOverflow.ellipsis),
                      ),
                      ...siteOptions.map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    selectedItemBuilder: (context) => [
                      const Text("All", overflow: TextOverflow.ellipsis),
                      ...siteOptions
                          .map((s) => Text(s, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: isOptionsLoading
                        ? null
                        : (v) => setState(() => selectedSite = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    label: const Text("Apply Filters"),
                    onPressed: isLoading || isOptionsLoading ? null : _load,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Reset"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ColorScheme cs, String error) {
    return Card(
      elevation: 0,
      color: cs.errorContainer.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              "Failed to load records",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onErrorContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onErrorContainer.withOpacity(0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, size: 48, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text(
              "No records found",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your timesheet records will appear here once you punch in/out. Try adjusting your filters.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(
      BuildContext context, ColorScheme cs, List<EngineerTimesheetRow> items) {
    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, idx) {
        final row = items[idx];
        final mark = (row.mark ?? "").trim().isEmpty ? "-" : row.mark!.trim();
        final isPresent = mark == "P";

        final markColor = isPresent
            ? (Theme.of(context).extension<AppColorsExtension>()?.success ??
                const Color(0xFF10B981))
            : cs.primary;

        final isAutoClosed =
            (row.remarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          clipBehavior: Clip.antiAlias,
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: markColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  AppFormatters.formatDateString(row.workDate),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  StatusChip(
                                      label: isPresent ? "Present" : mark,
                                      color: markColor),
                                  if (isAutoClosed)
                                    StatusChip(
                                      label: "AUTO CLOSED",
                                      color: Theme.of(context)
                                              .extension<AppColorsExtension>()
                                              ?.warning ??
                                          const Color(0xFFF59E0B),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if ((row.clientName ?? "").trim().isNotEmpty) ...[
                            Text(
                              row.clientName!.trim(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            row.projectName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 16, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  row.siteName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  cs.surfaceContainerHighest.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTimeColumn(
                                    context,
                                    label: "Punch In",
                                    time: AppFormatters.formatTime(
                                        row.punchInTime),
                                    icon: Icons.login_rounded,
                                    color: Theme.of(context)
                                            .extension<AppColorsExtension>()
                                            ?.success ??
                                        const Color(0xFF10B981),
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 32,
                                    color: cs.outlineVariant),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: _buildTimeColumn(
                                      context,
                                      label: "Punch Out",
                                      time: row.punchOutTime != null
                                          ? AppFormatters.formatTime(
                                              row.punchOutTime!)
                                          : "--:--",
                                      icon: Icons.logout_rounded,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 32,
                                    color: cs.outlineVariant),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Hours",
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppFormatters.formatHours(
                                              row.totalHours),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: cs.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((row.remarks ?? "").trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    cs.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: cs.outlineVariant.withOpacity(0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notes_rounded,
                                      size: 16, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isAutoClosed
                                          ? "System auto-closed"
                                          : row.remarks!.trim(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeColumn(BuildContext context,
      {required String label,
      required String time,
      required IconData icon,
      required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
