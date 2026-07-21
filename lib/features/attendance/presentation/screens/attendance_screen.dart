import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:sitepulse_engineer/features/attendance/presentation/bloc/stats/attendance_stats_bloc.dart';
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
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 1,
        title: Text(
          'Attendance Overview',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocBuilder<AttendanceStatsBloc, AttendanceStatsState>(
          builder: (context, state) {
            if (state.status == AttendanceStatsStatus.loading ||
                state.status == AttendanceStatsStatus.initial) {
              return _buildShimmerLoading(context);
            }
            
            if (state.status == AttendanceStatsStatus.error) {
              return _buildErrorState(context, state.errorMessage ?? "An error occurred");
            }

            final data = state.data;
            if (data == null) {
              return _buildErrorState(context, "No data available");
            }

            final totalDaysInMonth = DateUtils.getDaysInMonth(
                DateTime.now().year, DateTime.now().month);
            final daysPassed = DateTime.now().day;
            final absentDays = (daysPassed - data.totalPresentDays).clamp(0, 31);

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AttendanceStatsBloc>().add(
                      LoadAttendanceStatsRequested(
                          sessionToken: sessionToken,
                          month: DateFormat('yyyy-MM').format(DateTime.now())),
                    );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle(context, "Monthly Summary"),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: "Present",
                            value: "${data.totalPresentDays}",
                            subtitle: "Days",
                            icon: Icons.check_circle_rounded,
                            color: Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: "Absent",
                            value: "$absentDays",
                            subtitle: "Days",
                            icon: Icons.cancel_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: "Hours",
                            value: data.totalHours.toStringAsFixed(1),
                            subtitle: "Logged",
                            icon: Icons.access_time_filled_rounded,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionTitle(context, "Weekly Progress"),
                    const SizedBox(height: 16),
                    _WeeklyProgressCard(totalHours: data.totalHours),
                    
                    const SizedBox(height: 40),
                    _buildSectionTitle(context, "Attendance Timeline"),
                    const SizedBox(height: 16),
                    
                    if (data.items.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...data.items.take(10).map((item) => _PunchRow(item: item)),
                      
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final dateFormatter = DateFormat('EEEE, MMMM d');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateFormatter.format(now),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          "Your Attendance",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Track your monthly progress and timeline below.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 40,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Punches Found",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't punched in yet this month.",
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

  Widget _buildErrorState(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              "Failed to load attendance",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () {
                context.read<AttendanceStatsBloc>().add(
                      LoadAttendanceStatsRequested(
                          sessionToken: sessionToken,
                          month: DateFormat('yyyy-MM').format(DateTime.now())),
                    );
              },
              child: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ShimmerBox(width: 150, height: 24, borderRadius: 8),
        const SizedBox(height: 12),
        const ShimmerBox(width: 250, height: 32, borderRadius: 8),
        const SizedBox(height: 48),
        Row(
          children: const [
            Expanded(child: ShimmerBox(width: double.infinity, height: 130, borderRadius: 24)),
            SizedBox(width: 12),
            Expanded(child: ShimmerBox(width: double.infinity, height: 130, borderRadius: 24)),
            SizedBox(width: 12),
            Expanded(child: ShimmerBox(width: double.infinity, height: 130, borderRadius: 24)),
          ],
        ),
        const SizedBox(height: 40),
        const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
        const SizedBox(height: 40),
        const ShimmerBox(width: double.infinity, height: 80, borderRadius: 20),
        const SizedBox(height: 16),
        const ShimmerBox(width: double.infinity, height: 80, borderRadius: 20),
      ],
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
    final cs = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final double totalHours;

  const _WeeklyProgressCard({required this.totalHours});

  @override
  Widget build(BuildContext context) {
    final double targetHours = 48.0;
    final double progress = (totalHours / targetHours).clamp(0.0, 1.0);
    final cs = Theme.of(context).colorScheme;
    final isComplete = progress >= 1.0;
    final progressColor = isComplete 
        ? (Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981))
        : cs.primary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This Week",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Target: 48 hrs",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${totalHours.toStringAsFixed(1)} hrs",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ),
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
    final cs = Theme.of(context).colorScheme;
    
    final isPresent = item.mark == "P";
    final statusColor = isPresent
        ? (Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981))
        : (Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 24,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.workDate,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.login_rounded,
                                size: 14, color: Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              formatTime(item.punchInTime),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 14, color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 4),
                            Text(
                              item.punchOutTime != null
                                  ? formatTime(item.punchOutTime!)
                                  : "--:--",
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                StatusChip(
                  label: isPresent ? "Present" : (item.mark ?? "N/A"),
                  color: statusColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
