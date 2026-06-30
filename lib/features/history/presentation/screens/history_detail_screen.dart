import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sitepulse_engineer/core/utils/formatters.dart';
import 'package:sitepulse_engineer/shared/widgets/photo_gallery_row.dart';
import 'package:sitepulse_engineer/features/history/presentation/bloc/history_bloc.dart';

import '../../../../core/theme/app_colors_extension.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({
    super.key,
    required this.sessionToken,
    required this.attendanceLogId,
  });

  final String sessionToken;
  final String attendanceLogId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryBloc()
        ..add(LoadHistoryDetailRequested(
          sessionToken: sessionToken,
          attendanceLogId: attendanceLogId,
        )),
      child: const _HistoryDetailView(),
    );
  }
}

class _HistoryDetailView extends StatelessWidget {
  const _HistoryDetailView();

  Color _chipColor(BuildContext context, ColorScheme cs, String label) {
    final v = label.trim().toUpperCase();
    if (v == "P")
      return Theme.of(context).extension<AppColorsExtension>()!.successBg;
    if (v == "PUNCHED_IN")
      return Theme.of(context).colorScheme.primary.withAlpha(26);
    if (v == "PUNCHED_OUT")
      return Theme.of(context).extension<AppColorsExtension>()!.successBg;
    return cs.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Timesheet Details")),
      body: SafeArea(
        child: BlocBuilder<HistoryBloc, HistoryState>(
          builder: (context, state) {
            final isLoading = state.status == HistoryStatus.detailLoading ||
                state.status == HistoryStatus.initial;
            final error = state.status == HistoryStatus.detailError
                ? state.errorMessage
                : null;
            final d = state.detailData;

            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (error != null || d == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Failed to load details",
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(error ?? "Unknown error",
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }

            final isAutoClosed =
                (d.punchOutRemarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");

            return ListView(
              padding: const EdgeInsets.all(18),
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
                              child: Text(
                                d.workDate.trim().substring(0, 10),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _chipColor(context, cs, d.mark ?? ""),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ((d.mark ?? "").trim().isEmpty
                                    ? "-"
                                    : d.mark!.trim()),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2),
                              ),
                            ),
                            if (isAutoClosed) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .extension<AppColorsExtension>()!
                                      .warningBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "AUTO CLOSED",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        if ((d.clientName ?? "").trim().isNotEmpty) ...[
                          Text(d.clientName!.trim(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                        ],
                        Text(d.projectName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2)),
                        const SizedBox(height: 4),
                        Text(d.siteName,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Punch In",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(AppFormatters.formatTime(d.punchInTime),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Punch Out",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(AppFormatters.formatTime(d.punchOutTime),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Hours",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(AppFormatters.formatHours(d.totalHours),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if ((d.punchOutRemarks ?? "").trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text("Remark",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            isAutoClosed
                                ? "Closed by system"
                                : d.punchOutRemarks!.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                        PhotoGalleryRow(
                            label: "Punch-in photos", urls: d.punchInPhotoUrls),
                        PhotoGalleryRow(
                            label: "Punch-out photos",
                            urls: d.punchOutPhotoUrls),
                        PhotoGalleryRow(
                            label: "Progress photos",
                            urls: d.progressPhotoUrls),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
