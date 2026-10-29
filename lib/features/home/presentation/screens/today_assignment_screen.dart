import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import 'package:sitepulse_engineer/core/config/api_config.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/shared/models/auth_session.dart';
import 'package:sitepulse_engineer/features/profile/presentation/screens/profile_screen.dart';
import 'package:sitepulse_engineer/features/shell/presentation/screens/app_shell.dart';
import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/shared/widgets/primary_button.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';
import 'package:sitepulse_engineer/core/services/offline_punch_queue.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
import 'package:sitepulse_engineer/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:sitepulse_engineer/features/home/presentation/bloc/home_bloc.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:sitepulse_engineer/features/timesheet/presentation/screens/timesheet_screen.dart';
import 'package:sitepulse_engineer/features/timesheet/data/services/site_photo_service.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';
import 'package:sitepulse_engineer/shared/widgets/error_state_view.dart';
import 'package:sitepulse_engineer/shared/widgets/location_disclosure_dialog.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';
import 'package:sitepulse_engineer/core/services/offline_timesheet_queue.dart';
import 'package:sitepulse_engineer/core/services/shift_action_service.dart';
import 'package:sitepulse_engineer/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:sitepulse_engineer/core/services/notification_service.dart';
import 'package:sitepulse_engineer/features/onboarding/presentation/screens/complete_profile_screen.dart';
import 'package:uuid/uuid.dart';

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
  String? _expandedAssignmentId;
  bool isPunchingOutForException = false;
  String? _lastPunchOutRemarks;
  late Future<Map<String, dynamic>> _payoutEstimate;

  @override
  void initState() {
    super.initState();
    resolveApiBaseUrl();
    _payoutEstimate = _loadPayoutEstimate();
    ShiftActionService.punchOutRequests.addListener(_handlePunchOutAction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationsBloc>().add(
              const LoadNotificationsRequested(silent: true),
            );
        _consumePendingPunchOutAction();
      }
    });
  }

  Future<Map<String, dynamic>> _loadPayoutEstimate() async {
    final dio = await ApiClient.instance.dio;
    final response = await dio.get('/api/v1/engineer/payouts/estimate');
    return Map<String, dynamic>.from(response.data as Map);
  }

  num _payoutAmount(Map<String, dynamic> payout, String key) =>
      payout[key] as num? ?? 0;

  num _payoutDeductions(Map<String, dynamic> payout) =>
      _payoutAmount(payout, 'tds_amount') +
      _payoutAmount(payout, 'professional_tax_amount') +
      _payoutAmount(payout, 'employee_pf_amount') +
      _payoutAmount(payout, 'other_deductions');

  String _payoutMoney(dynamic value) =>
      '₹${(value as num? ?? 0).toStringAsFixed(2)}';

  String _payoutDays(dynamic value) {
    final amount = value as num? ?? 0;
    return amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);
  }

  Widget _buildPayoutStatChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _handlePunchOutAction() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _consumePendingPunchOutAction());
  }

  void _consumePendingPunchOutAction() {
    if (!mounted || !ShiftActionService.consumePendingPunchOut()) return;
    _punchOut();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  Future<double?> _resolveSiteDistance(TodayAssignmentModel assignment) async {
    if (assignment.latitude == 0 || assignment.longitude == 0) return null;
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
      return Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        assignment.latitude,
        assignment.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openMapDirections(String siteName) async {
    try {
      final query = Uri.encodeComponent(siteName);
      final geoUrl = Uri.parse("geo:0,0?q=$query");
      final webUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      debugPrint("Map launch error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch maps navigation")),
        );
      }
    }
  }

  @override
  void dispose() {
    ShiftActionService.punchOutRequests.removeListener(_handlePunchOutAction);
    super.dispose();
  }

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

  Future<void> _punchIn(String projectId, {String? exceptionReason}) async {
    final locationGranted =
        await LocationDisclosureDialog.showIfNeeded(context);
    if (!locationGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is required to punch in. On Android, select "While using the app" instead of "Only this time".',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }
    if (!mounted) return;

    final state = context.read<HomeBloc>().state;
    double? siteLat;
    double? siteLng;
    double? radius;
    if (state is HomeSuccess) {
      try {
        final a = state.response.assignments
            .firstWhere((a) => a.projectId == projectId);
        siteLat = a.latitude;
        siteLng = a.longitude;
        radius = a.allowedRadiusM.toDouble();
      } catch (_) {}
    }
    context.read<AttendanceBloc>().add(PunchInRequested(
          projectId: projectId,
          siteLat: siteLat,
          siteLng: siteLng,
          allowedRadiusM: radius,
          exceptionReason: exceptionReason,
        ));
  }

  Future<void> _punchOut(
      {String? remarks, String? exceptionReason, bool isRetry = false}) async {
    File? attachedFile;
    if (!isRetry) {
      final result = await _promptRemarks();
      if (result == null) return;

      remarks ??= result.remarks;
      _lastPunchOutRemarks = remarks;
      attachedFile = result.attachedFile;

      if (!mounted) return;

      if (attachedFile != null) {
        // Show loading overlay
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final homeState = context.read<HomeBloc>().state;
          String? activeProjectId;
          String? attendanceLogId;
          if (homeState is HomeSuccess) {
            activeProjectId = homeState.response.activeProjectId;
            attendanceLogId = homeState.response.activeAttendanceLogId;
          }

          final loc =
              await context.read<AttendanceBloc>().resolveLocationPublic();

          await SitePhotoService().uploadProgressPhoto(
            token: widget.sessionToken,
            file: attachedFile,
            lat: loc.lat,
            lng: loc.lng,
            addressText: remarks,
            projectName: "",
            siteName: "",
            projectId: activeProjectId,
            attendanceLogId: attendanceLogId,
            empCode: widget.engineerEmpCode,
            submissionTypeOverride: "REPORT",
            submissionContextOverride: "PUNCH_OUT_REPORT",
          );
        } catch (e) {
          final isOffline = ErrorHandler.isOfflineError(e);
          if (isOffline) {
            final homeState = context.read<HomeBloc>().state;
            String? activeProjectId;
            String? attendanceLogId;
            if (homeState is HomeSuccess) {
              activeProjectId = homeState.response.activeProjectId;
              attendanceLogId = homeState.response.activeAttendanceLogId;
            }
            final loc = await context
                .read<AttendanceBloc>()
                .resolveLocationPublic()
                .catchError((_) => (lat: 0.0, lng: 0.0, accuracyM: 0.0));
            await OfflineTimesheetQueue().add(OfflineTimesheet(
              id: Uuid().v4(),
              photoPath: attachedFile.path,
              lat: loc.lat,
              lng: loc.lng,
              addressText: remarks,
              projectName: "-",
              siteName: "-",
              projectId: activeProjectId,
              attendanceLogId: attendanceLogId,
              empCode: widget.engineerEmpCode,
              capturedAtIso: DateTime.now().toIso8601String(),
              submissionType: "REPORT",
              submissionContext: "PUNCH_OUT_REPORT",
            ));
          } else {
            if (mounted) {
              Navigator.of(context).pop(); // dismiss loading
              final appError = ErrorHandler.handle(e);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        "Failed to upload report: ${appError.userMessage}")),
              );
            }
            return;
          }
        }

        if (mounted) Navigator.of(context).pop(); // dismiss loading
      }
    } // Close if (!isRetry)
    if (!mounted) return;
    final state = context.read<HomeBloc>().state;
    double? siteLat;
    double? siteLng;
    double? radius;
    if (state is HomeSuccess) {
      try {
        final a = state.response.assignments
            .firstWhere((a) => a.projectId == selectedProjectIdForException);
        siteLat = a.latitude;
        siteLng = a.longitude;
        radius = a.allowedRadiusM.toDouble();
      } catch (_) {}
    }
    context.read<AttendanceBloc>().add(PunchOutRequested(
          remarks: remarks ?? _lastPunchOutRemarks ?? "",
          siteLat: siteLat,
          siteLng: siteLng,
          allowedRadiusM: radius,
          exceptionReason: exceptionReason,
        ));
  }

  Future<({String remarks, File? attachedFile})?> _promptRemarks() async {
    return showModalBottomSheet<({String remarks, File? attachedFile})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => const _PunchOutBottomSheet(),
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

  void _openProfileTab() {
    final shell = AppShellScope.maybeOf(context);
    if (shell != null) {
      shell.setIndex(4);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openProfileTab,
              borderRadius: BorderRadius.circular(32),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                child: Row(
                  children: [
                    ValueListenableBuilder<AuthSession?>(
                      valueListenable: SessionStore.notifier,
                      builder: (context, session, _) {
                        final rawPhotoUrl = session?.engineer.profilePhotoUrl;
                        final fullPhotoUrl = (rawPhotoUrl != null &&
                                rawPhotoUrl.trim().isNotEmpty)
                            ? resolveMaybeRelativeUrl(rawPhotoUrl)
                            : "";
                        final token = (session?.token ?? widget.sessionToken).trim();
                        final fallbackIcon = Icon(
                          Icons.person_rounded,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 32,
                        );

                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: ClipOval(
                            child: fullPhotoUrl.isNotEmpty
                                ? Image.network(
                                    fullPhotoUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    headers: token.isNotEmpty
                                        ? {"Authorization": "Bearer $token"}
                                        : null,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: fallbackIcon,
                                    ),
                                  )
                                : Center(child: fallbackIcon),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildNotificationBellButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationBellButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final unreadCount =
            (state is NotificationsLoaded) ? state.unreadCount : 0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  color: unreadCount > 0
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.notifications);
                },
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: TextStyle(
                        color: colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return FutureBuilder<int>(
      future: Future.wait(
              [OfflinePunchQueue().count(), OfflineTimesheetQueue().count()])
          .then((v) => v[0] + v[1]),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        final ext = Theme.of(context).extension<AppColorsExtension>();
        final warningColor = ext?.warning ?? Colors.orange;
        final warningBg =
            ext?.warningBg ?? Colors.orange.withValues(alpha: 0.1);

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
                        "$count items pending sync",
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

  Widget _buildIncompleteProfileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_rounded,
              color: Colors.amber.shade900, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Complete Your Profile",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Upload compliance documents and bank details to unlock punch-in.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const CompleteProfileScreen()),
              );
              if (mounted) {
                context.read<HomeBloc>().add(LoadAssignmentsRequested());
              }
            },
            child: const Text("Complete", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsListCard(List<TodayAssignmentModel> assignments,
      String? activeProjectId, bool isProfileComplete) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultExpandedProjectId = activeProjectId ?? assignments.first.projectId;

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
          if (!isProfileComplete)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Profile Incomplete",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Please upload your compliance documents & details when convenient.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.amber.shade200,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CompleteProfileScreen()),
                      );
                      if (mounted) {
                        context
                            .read<HomeBloc>()
                            .add(LoadAssignmentsRequested());
                      }
                    },
                    child: Text(
                      "Complete",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Divider
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5)),

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
              final isExpanded = _expandedAssignmentId == null
                  ? assignment.projectId == defaultExpandedProjectId
                  : _expandedAssignmentId == assignment.projectId;

              return _buildAssignmentRow(
                assignment,
                isAnyProjectActive,
                isThisProjectActive,
                isCompleted,
                isProfileComplete,
                isExpanded,
                () => setState(() {
                  _expandedAssignmentId =
                      isExpanded ? null : assignment.projectId;
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentRow(
      TodayAssignmentModel assignment,
      bool isAnyProjectActive,
      bool isThisProjectActive,
      bool isCompleted,
      bool isProfileComplete,
      bool isExpanded,
      VoidCallback onToggle) {
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
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
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
                        InkWell(
                          onTap: () =>
                              _openMapDirections(assignment.siteName),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
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
                const SizedBox(width: 8),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (isExpanded && assignment.todayPunchInTime != null) ...[
            const SizedBox(height: 12),
            FutureBuilder<double?>(
              future: _resolveSiteDistance(assignment),
              builder: (context, snapshot) {
                final resolvedDistance = snapshot.data;
                final punchInDist = assignment.todayPunchInDistanceM ?? resolvedDistance;
                final punchOutDist = assignment.todayPunchOutDistanceM ?? (assignment.todayPunchOutTime != null ? resolvedDistance : null);

                return _PunchSummaryCard(
                  punchInTimeStr: assignment.todayPunchInTime,
                  punchOutTimeStr: assignment.todayPunchOutTime,
                  activeHoursStr: assignment.todayActiveHours,
                  isActive: isThisProjectActive,
                  punchInDistanceMeters: punchInDist,
                  punchOutDistanceMeters: punchOutDist,
                  allowedRadiusM: assignment.allowedRadiusM,
                );
              },
            ),
          ],

          if (isExpanded && !isCompleted) ...[
            const SizedBox(height: 16),
            BlocBuilder<AttendanceBloc, AttendanceState>(
              builder: (context, attendanceState) {
                final isPunching = attendanceState is AttendanceLoading;
                final isThisLoading = isPunching &&
                    selectedProjectIdForException == assignment.projectId;

                if (isThisProjectActive) {
                  return Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: "Punch Out",
                          isLoading: isThisLoading,
                          isDestructive: true,
                          onPressed: isPunching
                              ? null
                              : () {
                                  setState(() {
                                    selectedProjectIdForException = assignment.projectId;
                                    isPunchingOutForException = true;
                                  });
                                  _punchOut();
                                },
                          icon: Icons.logout_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: "Work Update",
                          onPressed: isPunching
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TimesheetScreen(
                                        sessionToken: widget.sessionToken,
                                        engineerEmpCode: widget.engineerEmpCode,
                                      ),
                                    ),
                                  ),
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                    ],
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
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
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

  Widget _buildStatsTab({
    required String label,
    required int index,
    required ColorScheme cs,
  }) {
    final selected = _statsTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _statsTabIndex = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ),
      ),
    );
  }


  int _statsTabIndex = 0;

  Widget _buildExpectedPayoutTab(ColorScheme cs) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _payoutEstimate,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 76,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox(
            height: 76,
            child: Center(
              child: Text(
                'Expected payout is unavailable.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        final payout = snapshot.data!;
        final isEstimate = payout['is_estimate'] == true;
        final deductions = _payoutDeductions(payout);
        final paidDays = _payoutDays(payout['attendance_days']);
        final pendingDays = _payoutDays(payout['pending_exception_days']);
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _payoutMoney(payout['net_payout']),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gross: ${_payoutMoney(payout['gross_payout'])}  •  Deductions: ${_payoutMoney(deductions)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildPayoutStatChip(label: '$paidDays Paid Days', color: const Color(0xFF047857)),
                if (pendingDays != '0')
                  _buildPayoutStatChip(label: '$pendingDays Pending Review', color: const Color(0xFFB45309)),
              ],
            ),
            if (isEstimate) ...[
              const SizedBox(height: 10),
              Text(
                'Estimated amount. Final payout may change after review and adjustments.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCombinedStatsCard(
      AttendanceOverviewModel? overview, WeeklySummaryModel? summary, int projectCount) {
    if (overview == null && summary == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatsTab(label: "Today", index: 0, cs: cs)),
                        Expanded(child: _buildStatsTab(label: "Monthly", index: 1, cs: cs)),
                        Expanded(child: _buildStatsTab(label: "Expected Payout", index: 2, cs: cs)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _statsTabIndex == 2
                  ? _buildExpectedPayoutTab(cs)
                  : _statsTabIndex == 0
                  ? Row(
                      key: const ValueKey(0),
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Projects Assigned",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$projectCount",
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 40, color: cs.outlineVariant.withValues(alpha: 0.5)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Active Hours",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                overview?.activeHours ?? '0m',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey(1),
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Hours",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summary?.totalHours ?? '0m',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 40, color: cs.outlineVariant.withValues(alpha: 0.5)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Days Active",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${summary?.daysActive ?? 0}",
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralPromoCard() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withValues(alpha: 0.15), cs.secondary.withValues(alpha: 0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.referrals),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Refer & Earn Rewards",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "NEW JOBS",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Refer candidate resumes for open positions & earn cash bonuses!",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
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
                if (isPunchingOutForException) {
                  _punchOut(
                      remarks: _lastPunchOutRemarks,
                      exceptionReason: reason.trim(),
                      isRetry: true);
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
          unawaited(NotificationService.instance.showPunchInConfirmation());
          context.read<HomeBloc>().add(LoadAssignmentsRequested());
        } else if (state is PunchOutSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Punch Out Successful")));
          context.read<HomeBloc>().add(LoadAssignmentsRequested());
        } else if (state is PunchOfflineQueued) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
          context.read<HomeBloc>().add(LoadAssignmentsRequested());
          setState(() {});
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
            setState(() => _payoutEstimate = _loadPayoutEstimate());
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
                return ErrorStateView(
                  message: state.message,
                  onRetry: () =>
                      context.read<HomeBloc>().add(LoadAssignmentsRequested()),
                );
              }

              if (state is HomeSuccess) {
                final resp = state.response;
                final assignments = resp.assignments;
                final hasAssignment = resp.hasAssignment;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    _buildGreeting(),
                    _buildOfflineBanner(),
                    const SizedBox(height: 24),
                    _buildCombinedStatsCard(
                        resp.attendanceOverview, resp.weeklySummary, assignments.length),
                    const SizedBox(height: 24),
                    if (!hasAssignment) ...[
                      if (!resp.isProfileComplete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildIncompleteProfileCard(context),
                        ),
                      _buildEmptyState(),
                    ] else
                      _buildAssignmentsListCard(assignments,
                          resp.activeProjectId, resp.isProfileComplete),
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

class _PunchOutBottomSheet extends StatefulWidget {
  const _PunchOutBottomSheet();

  @override
  State<_PunchOutBottomSheet> createState() => _PunchOutBottomSheetState();
}

class _PunchOutBottomSheetState extends State<_PunchOutBottomSheet> {
  final _controller = TextEditingController();
  File? _selectedFile;
  bool _isPickingFile = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPickingFile = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorHandler.handle(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error selecting file: ${appError.userMessage}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
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
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Remarks (required)",
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedFile == null)
            OutlinedButton.icon(
              onPressed: _isPickingFile ? null : _pickFile,
              icon: _isPickingFile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_file_rounded),
              label: Text(_isPickingFile
                  ? "Opening File Picker..."
                  : "Attach Work Report (Optional)"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFile!.path.split('/').last,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Remarks are required")));
                return;
              }
              Navigator.of(context).pop((
                remarks: _controller.text.trim(),
                attachedFile: _selectedFile,
              ));
            },
            child: const Text("Confirm Punch Out"),
          ),
        ],
      ),
    );
  }
}

class _PunchSummaryCard extends StatefulWidget {
  final String? punchInTimeStr;
  final String? punchOutTimeStr;
  final String? activeHoursStr;
  final bool isActive;
  final double? punchInDistanceMeters;
  final double? punchOutDistanceMeters;
  final int allowedRadiusM;

  const _PunchSummaryCard({
    required this.punchInTimeStr,
    required this.punchOutTimeStr,
    required this.activeHoursStr,
    required this.isActive,
    required this.punchInDistanceMeters,
    required this.punchOutDistanceMeters,
    required this.allowedRadiusM,
  });

  @override
  State<_PunchSummaryCard> createState() => _PunchSummaryCardState();
}

class _PunchSummaryCardState extends State<_PunchSummaryCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initDuration();
    if (widget.isActive && widget.punchOutTimeStr == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _elapsed += const Duration(seconds: 1);
          });
        }
      });
    }
  }

  void _initDuration() {
    if (widget.activeHoursStr != null) {
      _elapsed = _parseDurationString(widget.activeHoursStr!);
    }
  }

  Duration _parseDurationString(String str) {
    try {
      int hours = 0;
      int minutes = 0;
      int seconds = 0;
      final parts = str.toLowerCase().split(RegExp(r'\s+'));
      for (final p in parts) {
        if (p.contains('h')) {
          hours = int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        } else if (p.contains('m')) {
          minutes = int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        } else if (p.contains('s')) {
          seconds = int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
      }
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    } catch (_) {
      return Duration.zero;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDistance = widget.punchInDistanceMeters != null;
    final isOutOfRadius = hasDistance && widget.allowedRadiusM > 0 && widget.punchInDistanceMeters! > widget.allowedRadiusM;
    final kmAway = hasDistance ? (widget.punchInDistanceMeters! / 1000).toStringAsFixed(2) : "";

    final statusBgColor = !hasDistance
        ? colorScheme.surface
        : (isOutOfRadius
            ? Colors.orange.shade50
            : const Color(0xFF10B981).withValues(alpha: 0.12));
    final statusBorderColor = !hasDistance
        ? colorScheme.outlineVariant.withValues(alpha: 0.3)
        : (isOutOfRadius
            ? Colors.orange.shade300
            : const Color(0xFF10B981).withValues(alpha: 0.3));
    final statusTextColor = !hasDistance
        ? colorScheme.onSurface
        : (isOutOfRadius
            ? Colors.orange.shade900
            : const Color(0xFF047857));
    final hasPunchOutDistance = widget.punchOutDistanceMeters != null;
    final isPunchOutOfRadius = hasPunchOutDistance &&
        widget.allowedRadiusM > 0 &&
        widget.punchOutDistanceMeters! > widget.allowedRadiusM;
    final punchOutKmAway = hasPunchOutDistance
        ? (widget.punchOutDistanceMeters! / 1000).toStringAsFixed(2)
        : "";
    final punchOutBgColor = !hasPunchOutDistance
        ? colorScheme.surface
        : (isPunchOutOfRadius
            ? Colors.orange.shade50
            : const Color(0xFF10B981).withValues(alpha: 0.12));
    final punchOutBorderColor = !hasPunchOutDistance
        ? colorScheme.outlineVariant.withValues(alpha: 0.3)
        : (isPunchOutOfRadius
            ? Colors.orange.shade300
            : const Color(0xFF10B981).withValues(alpha: 0.3));
    final punchOutTextColor = !hasPunchOutDistance
        ? colorScheme.onSurface
        : (isPunchOutOfRadius ? Colors.orange.shade900 : const Color(0xFF047857));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // PUNCH IN COLUMN
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.punchInTimeStr != null ? statusBgColor : colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.punchInTimeStr != null
                      ? statusBorderColor
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("PUNCH IN",
                          style: TextStyle(
                              color: widget.punchInTimeStr != null ? statusTextColor : colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      if (widget.punchInTimeStr != null && hasDistance) ...[
                        const SizedBox(width: 2),
                        Icon(
                          isOutOfRadius ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                          size: 11,
                          color: statusTextColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.punchInTimeStr ?? "-",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: widget.punchInTimeStr != null ? statusTextColor : colorScheme.onSurface),
                  ),
                  if (widget.punchInTimeStr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      !hasDistance
                          ? "Checking..."
                          : (isOutOfRadius ? "$kmAway KM" : "In Radius"),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // PUNCH OUT COLUMN
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.punchOutTimeStr != null
                    ? punchOutBgColor
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.punchOutTimeStr != null
                      ? punchOutBorderColor
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("PUNCH OUT",
                          style: TextStyle(
                              color: widget.punchOutTimeStr != null ? statusTextColor : colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      if (widget.punchOutTimeStr != null && hasPunchOutDistance) ...[
                        const SizedBox(width: 2),
                        Icon(
                          isPunchOutOfRadius
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          size: 11,
                          color: punchOutTextColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.punchOutTimeStr ?? "-",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: widget.punchOutTimeStr != null
                            ? punchOutTextColor
                            : colorScheme.onSurface),
                  ),
                  if (widget.punchOutTimeStr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      !hasPunchOutDistance
                          ? "Checking..."
                          : (isPunchOutOfRadius
                              ? "$punchOutKmAway KM"
                              : "In Radius"),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: punchOutTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // WORK DURATION COLUMN
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("WORK DURATION",
                      style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(
                    widget.punchOutTimeStr != null
                        ? (widget.activeHoursStr ?? "-")
                        : _formatDuration(_elapsed),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: colorScheme.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.punchOutTimeStr != null ? "Final Shift" : "Live Ticking",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
