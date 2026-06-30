import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/shared/widgets/primary_button.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
import 'package:sitepulse_engineer/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:sitepulse_engineer/features/home/presentation/bloc/home_bloc.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/features/shell/presentation/bloc/shell_bloc.dart';

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
        engineerName: engineerName,
        engineerEmpCode: engineerEmpCode,
      ),
    );
  }
}

class TodayAssignmentScreenView extends StatefulWidget {
  final String engineerName;
  final String engineerEmpCode;

  const TodayAssignmentScreenView({
    super.key,
    required this.engineerName,
    required this.engineerEmpCode,
  });

  @override
  State<TodayAssignmentScreenView> createState() =>
      _TodayAssignmentScreenViewState();
}

class _TodayAssignmentScreenViewState extends State<TodayAssignmentScreenView> {
  String? selectedProjectIdForException;

  Future<String?> _promptExceptionReason(BuildContext context) async {
    return showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text("Out of Radius"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                  hintText: "Reason for exception punch (required)"),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(controller.text),
                  child: const Text("Submit")),
            ],
          );
        });
  }

  void _punchIn(String projectId, {String? exceptionReason}) {
    context.read<AttendanceBloc>().add(PunchInRequested(
          projectId: projectId,
          exceptionReason: exceptionReason,
        ));
  }

  Future<void> _punchOut() async {
    final remarks = await _promptRemarks();
    if (remarks == null) return;

    if (!mounted) return;
    context.read<AttendanceBloc>().add(PunchOutRequested(
          remarks: remarks,
        ));
  }

  Future<String?> _promptRemarks() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 12, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Punch out",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                decoration:
                    const InputDecoration(hintText: "Remarks (required)"),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text("Confirm"),
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
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(40),
          child: Icon(Icons.person,
              color: Theme.of(context).colorScheme.primary, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back",
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                widget.engineerName,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .extension<AppColorsExtension>()!
                  .success
                  .withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline,
                color:
                    Theme.of(context).extension<AppColorsExtension>()!.success,
                size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            "You're all caught up!",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            "No assignments scheduled for today.",
            style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(TodayAssignmentModel assignment, bool canPunchIn,
      bool canPunchOut, bool isCompleted) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow:
            Theme.of(context).extension<AppColorsExtension>()!.softShadow,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(Icons.business_center,
                      color: Theme.of(context).colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TODAY's ASSIGNMENT",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignment.projectName,
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      letterSpacing: -0.2),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        assignment.siteName,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .extension<AppColorsExtension>()!
                                    .success
                                    .withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14,
                                      color: Theme.of(context)
                                          .extension<AppColorsExtension>()!
                                          .success),
                                  const SizedBox(width: 4),
                                  Text("COMPLETED",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .extension<AppColorsExtension>()!
                                              .success,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          else if (canPunchOut)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timelapse,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 4),
                                  Text("ACTIVE",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.all(20),
              child: BlocBuilder<AttendanceBloc, AttendanceState>(
                builder: (context, attendanceState) {
                  final isPunching = attendanceState is AttendanceLoading;
                  return Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: "Punch In",
                          isLoading: isPunching && canPunchIn,
                          onPressed: (canPunchIn && !isPunching)
                              ? () {
                                  selectedProjectIdForException =
                                      assignment.projectId;
                                  _punchIn(assignment.projectId);
                                }
                              : null,
                          icon: Icons.login,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: "Punch Out",
                          isLoading: isPunching && canPunchOut,
                          onPressed:
                              (canPunchOut && !isPunching) ? _punchOut : null,
                          icon: Icons.logout,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history,
                title: "History",
                color: const Color(0xFF6366F1),
                onTap: () =>
                    context.read<ShellBloc>().add(const ShellTabChanged(1)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.edit_note,
                title: "Work Update",
                color: const Color(0xFFF59E0B),
                onTap: () =>
                    context.read<ShellBloc>().add(const ShellTabChanged(2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.photo_camera,
                title: "Site Photos",
                color: const Color(0xFFEC4899),
                onTap: () =>
                    context.read<ShellBloc>().add(const ShellTabChanged(2)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.person_outline,
                title: "My Profile",
                color: const Color(0xFF10B981),
                onTap: () =>
                    context.read<ShellBloc>().add(const ShellTabChanged(3)),
              ),
            ),
          ],
        ),
      ],
    );
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
                _punchIn(selectedProjectIdForException!,
                    exceptionReason: reason.trim());
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(_dayDateTitle(),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16)),
          actions: [
            IconButton(
              onPressed: () =>
                  context.read<HomeBloc>().add(LoadAssignmentsRequested()),
              icon: Icon(Icons.refresh,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withAlpha(30),
                Theme.of(context).scaffoldBackgroundColor,
              ],
              stops: const [0.0, 0.4],
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<HomeBloc>().add(LoadAssignmentsRequested());
              },
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeInitial || state is HomeLoading) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      children: const [
                        ShimmerBox(
                            width: double.infinity,
                            height: 80,
                            borderRadius: 16),
                        SizedBox(height: 24),
                        ShimmerBox(
                            width: double.infinity,
                            height: 200,
                            borderRadius: 24),
                        SizedBox(height: 32),
                        ShimmerBox(width: 150, height: 24, borderRadius: 8),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: ShimmerBox(
                                    width: double.infinity,
                                    height: 110,
                                    borderRadius: 20)),
                            SizedBox(width: 16),
                            Expanded(
                                child: ShimmerBox(
                                    width: double.infinity,
                                    height: 110,
                                    borderRadius: 20)),
                          ],
                        )
                      ],
                    );
                  }

                  if (state is HomeError) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(child: Text("Error: ${state.message}"))
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      children: [
                        _buildGreeting(),
                        const SizedBox(height: 24),
                        if (!hasAssignment)
                          _buildEmptyState()
                        else
                          ...assignments.map((assignment) {
                            final isThisProjectActive =
                                resp.activeProjectId == assignment.projectId;
                            final isCompleted =
                                assignment.todayStatus == "COMPLETED";

                            final canPunchOut = isThisProjectActive;
                            final canPunchIn =
                                !isAnyProjectActive && !isCompleted;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildAssignmentCard(assignment,
                                  canPunchIn, canPunchOut, isCompleted),
                            );
                          }),
                        const SizedBox(height: 36),
                        _buildQuickActions(context),
                        const SizedBox(height: 20),
                      ],
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow:
              Theme.of(context).extension<AppColorsExtension>()!.softShadow,
          border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
