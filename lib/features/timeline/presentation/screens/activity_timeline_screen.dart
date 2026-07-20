import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:open_filex/open_filex.dart";
import "package:share_plus/share_plus.dart";

import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";
import "package:sitepulse_engineer/core/utils/ist_time.dart";
import "package:sitepulse_engineer/core/utils/formatters.dart";
import "package:sitepulse_engineer/shared/models/today_assignment.dart";
import "package:sitepulse_engineer/shared/widgets/primary_button.dart";
import "package:sitepulse_engineer/shared/widgets/section_header.dart";
import "package:sitepulse_engineer/shared/widgets/status_chip.dart";
import "package:sitepulse_engineer/shared/widgets/photo_gallery_row.dart";
import "package:sitepulse_engineer/features/timeline/presentation/bloc/timeline_bloc.dart";

class ActivityTimelineScreen extends StatelessWidget {
  const ActivityTimelineScreen({super.key, required this.sessionToken});

  final String sessionToken;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TimelineBloc()
        ..add(LoadTimelineRequested(sessionToken: sessionToken)),
      child: _ActivityTimelineView(sessionToken: sessionToken),
    );
  }
}

class _ActivityTimelineView extends StatefulWidget {
  const _ActivityTimelineView({required this.sessionToken});

  final String sessionToken;

  @override
  State<_ActivityTimelineView> createState() => _ActivityTimelineViewState();
}

class _ActivityTimelineViewState extends State<_ActivityTimelineView> {
  List<String> _monthOptions() {
    final now = IstTime.now();
    final out = <String>[""];
    for (var i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      out.add(
          "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}");
    }
    return out;
  }

  String _monthLabel(String value) =>
      value.trim().isEmpty ? "All months" : value;

  Future<void> _openFilters(BuildContext context, TimelineState state) async {
    String draftMonth = state.month;
    String draftStatus = state.statusFilter;

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Theme.of(context).colorScheme.onSurface.withAlpha(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Timeline Filters",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2)),
                    const SizedBox(height: 20),
                    const Text("Month",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: draftMonth,
                      decoration: inputDecoration,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      dropdownColor: Colors.white,
                      items: _monthOptions()
                          .map((m) => DropdownMenuItem<String>(
                              value: m, child: Text(_monthLabel(m))))
                          .toList(growable: false),
                      onChanged: (v) =>
                          setModalState(() => draftMonth = v ?? ""),
                    ),
                    const SizedBox(height: 16),
                    const Text("Status",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: draftStatus,
                      decoration: inputDecoration,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(
                            value: "ALL", child: Text("All status")),
                        DropdownMenuItem(
                            value: "PUNCHED_IN", child: Text("Punched In")),
                        DropdownMenuItem(
                            value: "PUNCHED_OUT", child: Text("Punched Out")),
                        DropdownMenuItem(
                            value: "COMPLETED", child: Text("Completed")),
                      ],
                      onChanged: (v) =>
                          setModalState(() => draftStatus = v ?? "ALL"),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              draftMonth = "";
                              draftStatus = "ALL";
                              Navigator.of(ctx).pop(true);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(20),
                                  width: 1.5),
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            child: const Text("Clear",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Apply",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
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

    if (applied != true || !context.mounted) return;

    final bloc = context.read<TimelineBloc>();
    bloc.add(FilterTimelineRequested(statusFilter: draftStatus));

    if (draftMonth != state.month) {
      bloc.add(LoadTimelineRequested(
          sessionToken: widget.sessionToken, month: draftMonth));
    }
  }

  List<EngineerHistoryRow> _filteredItems(
      List<EngineerHistoryRow> items, String statusFilter) {
    if (statusFilter == "ALL") return items;
    return items
        .where((item) => item.status.trim().toUpperCase() == statusFilter)
        .toList();
  }

  void _showPdfBottomSheet(
      BuildContext context, String fileName, String filePath) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Timeline PDF saved",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2)),
                const SizedBox(height: 8),
                Text(fileName,
                    style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: "Open PDF",
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await OpenFilex.open(filePath);
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: "Share PDF",
                  icon: Icons.share_outlined,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Share.shareXFiles([XFile(filePath)],
                        text: "My timeline PDF");
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Color _chipColor(BuildContext context, ColorScheme cs, String status) {
    final s = status.trim().toUpperCase();
    if (s == "COMPLETED" || s == "PUNCHED_OUT") {
      return Theme.of(context).extension<AppColorsExtension>()!.successBg;
    }
    if (s == "PUNCHED_IN") return cs.primary.withAlpha(26);
    return cs.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Timeline"),
        actions: [
          BlocBuilder<TimelineBloc, TimelineState>(
            builder: (context, state) {
              final isLoading = state.status == TimelineStatus.loading ||
                  state.status == TimelineStatus.initial;
              final isDownloading = state.status == TimelineStatus.downloading;
              return Row(
                children: [
                  IconButton(
                      onPressed:
                          isLoading ? null : () => _openFilters(context, state),
                      icon: const Icon(Icons.filter_alt_outlined)),
                  IconButton(
                      onPressed: isDownloading
                          ? null
                          : () {
                              context.read<TimelineBloc>().add(
                                  DownloadTimelinePdfRequested(
                                      sessionToken: widget.sessionToken,
                                      month: state.month));
                            },
                      icon: const Icon(Icons.download_outlined)),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<TimelineBloc, TimelineState>(
          listener: (context, state) {
            if (state.status == TimelineStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Theme.of(context).colorScheme.error,
              ));
            } else if (state.status == TimelineStatus.downloadSuccess) {
              if (state.downloadedFileName != null &&
                  state.downloadedFilePath != null) {
                _showPdfBottomSheet(
                  context,
                  state.downloadedFileName!,
                  state.downloadedFilePath!,
                );
              }
            }
          },
          builder: (context, state) {
            final isLoading = state.status == TimelineStatus.loading ||
                state.status == TimelineStatus.initial;
            final items = _filteredItems(
                state.data?.items ?? const <EngineerHistoryRow>[],
                state.statusFilter);

            return RefreshIndicator(
              onRefresh: () async {
                context.read<TimelineBloc>().add(
                    LoadTimelineRequested(
                        sessionToken: widget.sessionToken,
                        month: state.month));
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                          child: SectionHeader(title: "Activity Timeline")),
                      if (state.month.trim().isNotEmpty)
                        StatusChip(
                            label: _monthLabel(state.month),
                            color: cs.primaryContainer),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading) const LinearProgressIndicator(),
                  if (state.status == TimelineStatus.error &&
                      state.data == null) ...[
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
                                .error
                                .withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 32),
                          const SizedBox(height: 16),
                          const Text("Failed to load timeline",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 8),
                          Text(state.errorMessage,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 20),
                          PrimaryButton(
                              label: "Retry",
                              onPressed: () {
                                context.read<TimelineBloc>().add(
                                    LoadTimelineRequested(
                                        sessionToken: widget.sessionToken,
                                        month: state.month));
                              },
                              icon: Icons.refresh),
                        ],
                      ),
                    ),
                    const Spacer(),
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
                                .withAlpha(10)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.timeline_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 32),
                          const SizedBox(height: 16),
                          const Text("No activity yet",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 8),
                          Text(
                              "Punch in/out and submit work updates to build your timeline.",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                        ],
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
                          final chip = _chipColor(context, cs, row.status);
                          final isAutoClosed = _isSystemAutoClosed(row.remarks);
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: Theme.of(context)
                                  .extension<AppColorsExtension>()!
                                  .softShadow,
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(10)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(width: 6, color: chip),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    AppFormatters
                                                        .formatDateString(
                                                            row.workDate),
                                                    style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        letterSpacing: -0.2),
                                                  ),
                                                ),
                                                if (row.status
                                                    .trim()
                                                    .isNotEmpty)
                                                  StatusChip(
                                                      label: row.status,
                                                      color: chip),
                                                if (isAutoClosed) ...[
                                                  const SizedBox(width: 8),
                                                  StatusChip(
                                                      label: "AUTO CLOSED",
                                                      color: Theme.of(context)
                                                          .extension<
                                                              AppColorsExtension>()!
                                                          .warningBg),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(row.projectName,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18,
                                                    letterSpacing: -0.2)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on_outlined,
                                                    size: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(row.siteName,
                                                      style: TextStyle(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(10),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text("Punch In",
                                                            style: TextStyle(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800)),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                            AppFormatters
                                                                .formatTime(row
                                                                    .punchInTime),
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text("Punch Out",
                                                            style: TextStyle(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800)),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                            AppFormatters
                                                                .formatTime(row
                                                                    .punchOutTime),
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_displayRemarks(row.remarks)
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: isAutoClosed
                                                      ? Theme.of(context)
                                                          .extension<
                                                              AppColorsExtension>()!
                                                          .warningBg
                                                          .withAlpha(20)
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withAlpha(10),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: isAutoClosed
                                                          ? Theme.of(context)
                                                              .extension<
                                                                  AppColorsExtension>()!
                                                              .warningBg
                                                              .withAlpha(50)
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                              .withAlpha(20)),
                                                ),
                                                child: Text(
                                                  _displayRemarks(row.remarks),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (row.punchInPhotoUrls
                                                    .isNotEmpty ||
                                                row.punchOutPhotoUrls
                                                    .isNotEmpty ||
                                                row.progressPhotoUrls
                                                    .isNotEmpty)
                                              const SizedBox(height: 16),
                                            PhotoGalleryRow(
                                                label: "Punch-in photos",
                                                urls: row.punchInPhotoUrls),
                                            PhotoGalleryRow(
                                                label: "Punch-out photos",
                                                urls: row.punchOutPhotoUrls),
                                            PhotoGalleryRow(
                                                label: "Work updates",
                                                urls: row.progressPhotoUrls),
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
                      ),
                    ),
                  ],
                ],
              ),
              )
            );
          },
        ),
      ),
    );
  }
}
