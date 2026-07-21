import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/shared/widgets/primary_button.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';
import 'package:sitepulse_engineer/core/services/offline_punch_queue.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
import 'package:sitepulse_engineer/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:sitepulse_engineer/features/home/presentation/bloc/home_bloc.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/features/shell/presentation/bloc/shell_bloc.dart';
import 'package:sitepulse_engineer/features/history/presentation/screens/history_screen.dart';
import 'package:sitepulse_engineer/features/attendance/presentation/screens/attendance_screen.dart';

class TodayAssignmentScreen extends StatelessWidget {
  const TodayAssignmentScreen({
    super.key,
    required this.sessionToken,
    required this.engineerName,
    required this.engineerEmpCode,
  });

  final String sessionToken;
  final String engineerName;
  final String engineerEmpCode;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => HomeBloc()..add(LoadAssignmentsRequested())),
        BlocProvider(create: (_) => AttendanceBloc()),
      ],
      child: TodayAssignmentScreenView(
        sessionToken: sessionToken,
        engineerName: engineerName,
        engineerEmpCode: engineerEmpCode,
      ),
    );
  }
}

class TodayAssignmentScreenView extends StatefulWidget {
  final String sessionToken;
  final String engineerName;
  final String engineerEmpCode;

  const TodayAssignmentScreenView({
    super.key,
    required this.sessionToken,
    required this.engineerName,
    required this.engineerEmpCode,
  });

  @override
  State<TodayAssignmentScreenView> createState() =>
      _TodayAssignmentScreenViewState();
}

class _TodayAssignmentScreenViewState extends State<TodayAssignmentScreenView> {
  String? selectedProjectIdForException;
  bool isPunchingOutForException = false;
  String? _lastPunchOutRemarks;

  Future<String?> _promptExceptionReason(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Out of Radius",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "You are attempting to punch from outside the designated project location. Please provide a reason.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Reason for exception punch",
                  hintText: "e.g., Authorized off-site work",
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(controller.text),
                    child: const Text("Submit"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _punchIn(String projectId, {String? exceptionReason}) {
    context.read<AttendanceBloc>().add(PunchInRequested(
          projectId: projectId,
          exceptionReason: exceptionReason,
        ));
  }

  Future<void> _punchOut({String? remarks, String? exceptionReason}) async {
    remarks ??= await _promptRemarks();
    if (remarks == null) return;
    _lastPunchOutRemarks = remarks;

    if (!mounted) return;
    context.read<AttendanceBloc>().add(PunchOutRequested(
          remarks: remarks,
          exceptionReason: exceptionReason,
        ));
  }

  Future<String?> _promptRemarks() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Punch out",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please provide a brief summary of the work completed.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Remarks (required)",
                  hintText: "What did you work on?",
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text("Confirm Punch Out"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _dayDateTitle() {
    const weekdays = <String>[
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    const months = <String>[
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    final now = IstTime.now();
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return "$weekday, ${now.day.toString().padLeft(2, "0")} $month ${now.year}";
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.person_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.engineerName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return FutureBuilder<int>(
      future: OfflinePunchQueue().count(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        final ext = Theme.of(context).extension<AppColorsExtension>();
        final warningColor = ext?.warning ?? Colors.orange;
        final warningBg = ext?.warningBg ?? Colors.orange.withValues(alpha: 0.1);

        return Card(
          elevation: 0,
          color: warningBg,
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: warningColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: warningColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Offline Mode Active",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: warningColor,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$count punches pending sync",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: warningColor.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: warningColor,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "You're all caught up!",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "No assignments scheduled for today.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentsListCard(
      List<TodayAssignmentModel> assignments, String? activeProjectId) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Unified Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.business_center_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S ASSIGNMENTS",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${assignments.length} Projects",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Divider(
              height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),

          // List of Assignments
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: assignments.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final isThisProjectActive =
                  activeProjectId == assignment.projectId;
              final isAnyProjectActive = activeProjectId != null;
              final isCompleted = assignment.todayStatus == "COMPLETED";

              return _buildAssignmentRow(
                assignment,
                isAnyProjectActive,
                isThisProjectActive,
                isCompleted,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentRow(TodayAssignmentModel assignment,
      bool isAnyProjectActive, bool isThisProjectActive, bool isCompleted) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<AppColorsExtension>();
    final successColor = ext?.success ?? Colors.green;

    final rowColor = isThisProjectActive
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : Colors.transparent;

    return Container(
      color: rowColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.projectName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            assignment.siteName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (assignment.todayActiveHours != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            "Today: ${assignment.todayActiveHours}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                    if (assignment.todayPunchInTime != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Punch In",
                                      style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                      assignment.todayPunchInTime!,
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
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                      assignment.todayPunchOutTime ?? "-",
                                      style: const TextStyle(fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCompleted)
                _StatusChip(
                  icon: Icons.check_circle_rounded,
                  label: "COMPLETED",
                  color: successColor,
                )
              else if (isThisProjectActive)
                const _PulsingActiveBadge(),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 16),
            BlocBuilder<AttendanceBloc, AttendanceState>(
              builder: (context, attendanceState) {
                final isPunching = attendanceState is AttendanceLoading;
                final isThisLoading = isPunching &&
                    selectedProjectIdForException == assignment.projectId;

                if (isThisProjectActive) {
                  return PrimaryButton(
                    label: "Punch Out",
                    isLoading: isThisLoading,
                    isDestructive: true,
                    onPressed: isPunching
                        ? null
                        : () {
                            setState(() {
                              selectedProjectIdForException =
                                  assignment.projectId;
                              isPunchingOutForException = true;
                            });
                            _punchOut();
                          },
                    icon: Icons.logout_rounded,
                  );
                } else if (!isAnyProjectActive) {
                  return PrimaryButton(
                    label: "Punch In",
                    isLoading: isThisLoading,
                    onPressed: isPunching
                        ? null
                        : () {
                            setState(() {
                              selectedProjectIdForException =
                                  assignment.projectId;
                              isPunchingOutForException = false;
                            });
                            _punchIn(assignment.projectId);
                          },
                    icon: Icons.login_rounded,
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Please punch out of the active project first.",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildAttendanceOverviewCard(AttendanceOverviewModel? overview) {
    if (overview == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<AppColorsExtension>();
    final isOnline = overview.currentStatus == "ON SITE";
    final statusColor =
        isOnline ? (ext?.success ?? Colors.green) : cs.onSurfaceVariant;

    return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AttendanceScreen(sessionToken: widget.sessionToken),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined,
                            color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "TODAY'S OVERVIEW",
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                        ),
                      ],
                    ),
                    _StatusChip(
                      icon: Icons.circle,
                      label: overview.currentStatus,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "First Punch-in",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            overview.firstPunchIn ?? "--:--",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 40,
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Active Hours",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            overview.activeHours,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
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
        ));
  }

  Widget _buildWeeklySummaryCard(WeeklySummaryModel? summary) {
    if (summary == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    HistoryScreen(sessionToken: widget.sessionToken),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.date_range_rounded,
                        color: cs.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "MONTHLY SUMMARY",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Hours",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary.totalHours,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 40,
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Days Active",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${summary.daysActive}",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
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
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AttendanceBloc, AttendanceState>(
      listener: (context, state) {
        if (state is AttendanceError) {
          if (state.message == 'OUT_OF_RADIUS_REASON_REQUIRED') {
            _promptExceptionReason(context).then((reason) {
              if (reason != null &&
                  reason.trim().isNotEmpty &&
                  selectedProjectIdForException != null) {
                if (isPunchingOutForException) {
                  _punchOut(
                      remarks: _lastPunchOutRemarks,
                      exceptionReason: reason.trim());
                } else {
                  _punchIn(selectedProjectIdForException!,
                      exceptionReason: reason.trim());
                }
              }
            });
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        } else if (state is PunchInSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Punch In Successful")));
          context.read<HomeBloc>().add(LoadAssignmentsRequested());
        } else if (state is PunchOutSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Punch Out Successful")));
          context.read<HomeBloc>().add(LoadAssignmentsRequested());
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          scrolledUnderElevation: 1,
          title: Text(
            _dayDateTitle(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(LoadAssignmentsRequested());
          },
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeInitial || state is HomeLoading) {
                return ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: const [
                    ShimmerBox(
                        width: double.infinity, height: 80, borderRadius: 24),
                    SizedBox(height: 24),
                    ShimmerBox(
                        width: double.infinity, height: 200, borderRadius: 24),
                    SizedBox(height: 32),
                    ShimmerBox(width: 150, height: 24, borderRadius: 8),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: ShimmerBox(
                                width: double.infinity,
                                height: 110,
                                borderRadius: 24)),
                        SizedBox(width: 16),
                        Expanded(
                            child: ShimmerBox(
                                width: double.infinity,
                                height: 110,
                                borderRadius: 24)),
                      ],
                    )
                  ],
                );
              }

              if (state is HomeError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Text(
                        "Error: ${state.message}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  ],
                );
              }

              if (state is HomeSuccess) {
                final resp = state.response;
                final assignments = resp.assignments;
                final hasAssignment = resp.hasAssignment;
                final isAnyProjectActive = (resp.activeProjectId != null);

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    _buildGreeting(),
                    _buildOfflineBanner(),
                    const SizedBox(height: 24),
                    _buildAttendanceOverviewCard(resp.attendanceOverview),
                    const SizedBox(height: 16),
                    _buildWeeklySummaryCard(resp.weeklySummary),
                    const SizedBox(height: 32),
                    if (!hasAssignment)
                      _buildEmptyState()
                    else
                      _buildAssignmentsListCard(
                          assignments, resp.activeProjectId),
                    const SizedBox(height: 40),
                  ],
                );
              }

              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _PulsingActiveBadge extends StatefulWidget {
  const _PulsingActiveBadge();

  @override
  State<_PulsingActiveBadge> createState() => _PulsingActiveBadgeState();
}

class _PulsingActiveBadgeState extends State<_PulsingActiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: _opacityAnimation.value * 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: _opacityAnimation.value * 0.3),
                width: 1,
              )),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse_rounded,
                  size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text("ACTIVE",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
        );
      },
    );
  }
}
