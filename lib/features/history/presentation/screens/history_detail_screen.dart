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
    if (v == "P") {
      return Theme.of(context).extension<AppColorsExtension>()?.successBg ?? const Color(0xFFD1FAE5);
    }
    if (v == "PUNCHED_IN") {
      return cs.primary.withAlpha(26);
    }
    if (v == "PUNCHED_OUT") {
      return Theme.of(context).extension<AppColorsExtension>()?.successBg ?? const Color(0xFFD1FAE5);
    }
    return cs.primaryContainer;
  }
  
  Color _chipTextColor(BuildContext context, ColorScheme cs, String label) {
    final v = label.trim().toUpperCase();
    if (v == "P" || v == "PUNCHED_OUT") {
      return Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981);
    }
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 1,
        title: Text(
          "Timesheet Details",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
      ),
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
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                      const SizedBox(height: 16),
                      Text("Failed to load details",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                      const SizedBox(height: 10),
                      Text(error ?? "Unknown error",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.error,
                                fontWeight: FontWeight.w600,
                              )),
                    ],
                  ),
                ),
              );
            }

            final isAutoClosed =
                (d.punchOutRemarks ?? "").startsWith("SYSTEM_AUTO_CLOSED");

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                _buildHeaderCard(context, cs, d, isAutoClosed),
                const SizedBox(height: 16),
                _buildAssignmentDetailsCard(context, cs, d),
                const SizedBox(height: 16),
                _buildTimeMetricsCard(context, cs, d, isAutoClosed),
                const SizedBox(height: 24),
                
                if (d.punchInPhotoUrls.isNotEmpty || 
                    d.punchOutPhotoUrls.isNotEmpty || 
                    d.progressPhotoUrls.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      "Attachments",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                  ),
                  if (d.punchInPhotoUrls.isNotEmpty)
                    _buildGalleryContainer(context, cs, "Punch-in Photos", d.punchInPhotoUrls),
                  if (d.punchOutPhotoUrls.isNotEmpty)
                    _buildGalleryContainer(context, cs, "Punch-out Photos", d.punchOutPhotoUrls),
                  if (d.progressPhotoUrls.isNotEmpty)
                    _buildGalleryContainer(context, cs, "Progress Photos", d.progressPhotoUrls),
                ],
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ColorScheme cs, dynamic d, bool isAutoClosed) {
    final mark = ((d.mark ?? "").trim().isEmpty ? "-" : d.mark!.trim());
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Work Date",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.workDate.trim().substring(0, 10),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _chipColor(context, cs, d.mark ?? ""),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mark,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _chipTextColor(context, cs, d.mark ?? ""),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (isAutoClosed) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).extension<AppColorsExtension>()?.warningBg ?? const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "AUTO CLOSED",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentDetailsCard(BuildContext context, ColorScheme cs, dynamic d) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((d.clientName ?? "").trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.clientName!.trim(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              d.projectName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 16),
            _buildIconRow(
              context,
              icon: Icons.location_city_rounded,
              label: d.siteName,
            ),
            if ((d.address ?? "").trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildIconRow(
                context,
                icon: Icons.location_on_rounded,
                label: d.address!.trim(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow(BuildContext context, {required IconData icon, required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeMetricsCard(BuildContext context, ColorScheme cs, dynamic d, bool isAutoClosed) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTimeColumn(
                    context,
                    label: "Punch In",
                    time: AppFormatters.formatTime(d.punchInTime),
                    icon: Icons.login_rounded,
                    color: Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981),
                  ),
                ),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _buildTimeColumn(
                      context,
                      label: "Punch Out",
                      time: d.punchOutTime != null ? AppFormatters.formatTime(d.punchOutTime!) : "--:--",
                      icon: Icons.logout_rounded,
                      color: cs.error,
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hours Logged",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormatters.formatHours(d.totalHours),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
            if ((d.punchOutRemarks ?? "").trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes_rounded, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          "Remarks",
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAutoClosed ? "Closed by system" : d.punchOutRemarks!.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn(BuildContext context, {required String label, required String time, required IconData icon, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
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
        const SizedBox(height: 6),
        Text(
          time,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildGalleryContainer(BuildContext context, ColorScheme cs, String title, List<String> urls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: PhotoGalleryRow(label: title, urls: urls),
      ),
    );
  }
}
