import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:sitepulse_engineer/features/attendance/presentation/bloc/stats/attendance_stats_bloc.dart';
import 'package:sitepulse_engineer/shared/widgets/section_header.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
import 'package:sitepulse_engineer/shared/widgets/status_chip.dart';
import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';

class AttendanceScreen extends StatelessWidget {
  final String sessionToken;

  const AttendanceScreen({super.key, required this.sessionToken});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceStatsBloc()
        ..add(LoadAttendanceStatsRequested(
            sessionToken: sessionToken,
            month: DateFormat('yyyy-MM').format(DateTime.now()))),
      child: _AttendanceView(sessionToken: sessionToken),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  final String sessionToken;

  const _AttendanceView({required this.sessionToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: BlocBuilder<AttendanceStatsBloc, AttendanceStatsState>(
            builder: (context, state) {
              if (state.status == AttendanceStatsStatus.loading ||
                  state.status == AttendanceStatsStatus.initial) {
                return ListView(
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(
                            child: ShimmerBox(
                                width: double.infinity,
                                height: 110,
                                borderRadius: 20)),
                        SizedBox(width: 12),
                        Expanded(
                            child: ShimmerBox(
                                width: double.infinity,
                                height: 110,
                                borderRadius: 20)),
                        SizedBox(width: 12),
                        Expanded(
                            child: ShimmerBox(
                                width: double.infinity,
                                height: 110,
                                borderRadius: 20)),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const ShimmerBox(
                        width: double.infinity, height: 100, borderRadius: 20),
                    const SizedBox(height: 36),
                    const ShimmerBox(
                        width: double.infinity, height: 80, borderRadius: 16),
                    const SizedBox(height: 12),
                    const ShimmerBox(
                        width: double.infinity, height: 80, borderRadius: 16),
                    const SizedBox(height: 12),
                    const ShimmerBox(
                        width: double.infinity, height: 80, borderRadius: 16),
                  ],
                );
              }
              if (state.status == AttendanceStatsStatus.error) {
                return Center(
                  child: Text("Failed to load: ${state.errorMessage}",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                );
              }

              final data = state.data;
              if (data == null) {
                return const Center(child: Text("No data available"));
              }

              final totalDaysInMonth = DateUtils.getDaysInMonth(
                  DateTime.now().year, DateTime.now().month);
              // Rough calculation for absent days (excluding future days)
              final daysPassed = DateTime.now().day;
              final absentDays =
                  (daysPassed - data.totalPresentDays).clamp(0, 31);

              return RefreshIndicator(
                  onRefresh: () async {
                    context.read<AttendanceStatsBloc>().add(
                        LoadAttendanceStatsRequested(
                            sessionToken: sessionToken,
                            month:
                                DateFormat('yyyy-MM').format(DateTime.now())));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: "Monthly Summary"),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                title: "Present",
                                value: "${data.totalPresentDays}",
                                subtitle: "Days",
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                title: "Absent",
                                value: "$absentDays",
                                subtitle: "Days",
                                icon: Icons.cancel_rounded,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                title: "Hours",
                                value: data.totalHours.toStringAsFixed(1),
                                subtitle: "Logged",
                                icon: Icons.access_time_filled_rounded,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(title: "Weekly Progress"),
                        const SizedBox(height: 12),
                        _WeeklyProgressCard(totalHours: data.totalHours),
                        const SizedBox(height: 24),
                        const SectionHeader(title: "Recent Punches"),
                        const SizedBox(height: 12),
                        if (data.items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40),
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
                                      .withAlpha(8)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.history_toggle_off_rounded,
                                      size: 40,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No Punches Found",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "You haven't punched in yet this month.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...data.items
                              .take(5)
                              .map((item) => _PunchRow(item: item)),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ));
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.softShadow,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withAlpha(150)),
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final double totalHours;

  const _WeeklyProgressCard({required this.totalHours});

  @override
  Widget build(BuildContext context) {
    // Assuming a standard 48 hour week for field engineers
    final double targetHours = 48.0;
    final double progress = (totalHours / targetHours).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.softShadow,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "This Week",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              Text(
                "${totalHours.toStringAsFixed(1)} / 48 hrs",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withAlpha(15),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? const Color(0xFF10B981)
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchRow extends StatelessWidget {
  final dynamic item; // EngineerTimesheetRow

  const _PunchRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final formatTime =
        (DateTime dt) => DateFormat.jm().format(IstTime.toIst(dt));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.softShadow,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded,
                size: 24, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.workDate,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  item.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.login_rounded,
                        size: 14, color: const Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(formatTime(item.punchInTime),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Icon(Icons.logout_rounded,
                        size: 14, color: const Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text(
                        item.punchOutTime != null
                            ? formatTime(item.punchOutTime!)
                            : "--:--",
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          StatusChip(
            label: item.mark == "P" ? "Present" : (item.mark ?? "N/A"),
            color: item.mark == "P"
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}
