import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/network/network_info.dart";
import "package:sitepulse_engineer/shared/models/auth_session.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/services/offline_punch_sync_service.dart";
import "package:sitepulse_engineer/core/services/offline_timesheet_sync_service.dart";
import "package:sitepulse_engineer/core/services/persistent_background_tracking_service.dart";
import "package:sitepulse_engineer/core/services/mobile_policy_service.dart";
import "package:sitepulse_engineer/features/home/presentation/screens/today_assignment_screen.dart";
import "package:sitepulse_engineer/features/history/data/services/history_service.dart";
import "package:sitepulse_engineer/features/timesheet/data/services/timesheet_service.dart";
import "package:sitepulse_engineer/features/profile/presentation/screens/profile_screen.dart";
import "package:intl/intl.dart";
import "package:sitepulse_engineer/features/timeline/presentation/screens/activity_timeline_screen.dart";
import "package:sitepulse_engineer/features/referrals/presentation/screens/referrals_home_screen.dart";
import "package:sitepulse_engineer/features/referrals/data/services/referral_job_badge_service.dart";
import "package:sitepulse_engineer/features/documents/presentation/screens/document_upload_screen.dart";
import "package:sitepulse_engineer/features/documents/presentation/bloc/documents_bloc.dart";
import "package:sitepulse_engineer/shared/models/engineer_document_model.dart";
import "package:sitepulse_engineer/shared/utils/dialog_utils.dart";
import "package:sitepulse_engineer/features/shell/presentation/bloc/shell_bloc.dart";
import "../../../../core/services/offline_document_sync_service.dart";
import "../../../home/presentation/bloc/home_bloc.dart";
import "package:sitepulse_engineer/features/onboarding/data/models/onboarding_status_model.dart";
import "package:sitepulse_engineer/shared/widgets/location_disclosure_dialog.dart";
import "package:sitepulse_engineer/features/onboarding/presentation/widgets/complete_profile_dialog.dart";

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.index,
    required this.setIndex,
    required super.child,
  });

  final int index;
  final void Function(int) setIndex;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) => index != oldWidget.index;
}

class AppShell extends StatelessWidget {
  final int initialTab;
  const AppShell({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ShellBloc(initialIndex: initialTab)),
        BlocProvider(
          create: (_) => DocumentsBloc()
            ..add(LoadDocumentsRequested(
                sessionToken: (SessionStore.current?.token ?? "").trim())),
        ),
      ],
      child: const _AppShellView(),
    );
  }
}

class _AppShellView extends StatefulWidget {
  const _AppShellView();

  @override
  State<_AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<_AppShellView>
    with WidgetsBindingObserver {
  Timer? _offlineSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _networkStatusSubscription;
  String? _offlineSyncToken;
  String? _referralBadgeEngineerId;
  late final NetworkInfo _networkInfo;
  bool _isOffline = false;

  void _refreshReferralJobBadge(String engineerId) {
    if (_referralBadgeEngineerId == engineerId) return;
    _referralBadgeEngineerId = engineerId;
    unawaited(ReferralJobBadgeService.instance.refresh(engineerId: engineerId));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _networkInfo = NetworkInfoImpl(Connectivity());
    _checkNetworkStatus();
    _networkStatusSubscription = _networkInfo.onConnectivityChanged.listen(
      (results) => _setOffline(results.contains(ConnectivityResult.none)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        SessionStore.syncProfile();
        await MobilePolicyService.loadCached();
        await MobilePolicyService.refresh();
        await LocationDisclosureDialog.showIfNeeded(context);
        await PersistentBackgroundTrackingService.reconcileWithServer();
        if (mounted) {
          await CompleteProfileDialog.showIfNeeded(context);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineSyncTimer?.cancel();
    _networkStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PersistentBackgroundTrackingService.reconcileWithServer());
      unawaited(MobilePolicyService.refresh());
      _checkNetworkStatus();
    }
  }

  Future<void> _checkNetworkStatus() async {
    final isConnected = await _networkInfo.isConnected;
    _setOffline(!isConnected);
  }

  void _setOffline(bool offline) {
    if (!mounted || _isOffline == offline) return;
    setState(() => _isOffline = offline);
  }

  void _startOfflineSync(String token) {
    if (_offlineSyncToken == token && _offlineSyncTimer != null) return;
    _offlineSyncTimer?.cancel();
    _offlineSyncToken = token;
    final svc = OfflinePunchSyncService();
    final timesheetSvc = OfflineTimesheetSyncService();
    final documentSvc = OfflineDocumentSyncService();

    // Proactively cache timeline and timesheets on app load.
    // Use fire-and-forget async closures — .catchError((_) => null) is invalid
    // when the Future type is not nullable, causing an Unhandled Exception that
    // blocks Flutter's frame cycle and prevents navigation from working.
    () async {
      try {
        await HistoryService().history(token: token);
      } catch (_) {}
    }();
    () async {
      try {
        await TimesheetService().timesheets(
          token: token,
          month: DateFormat('yyyy-MM').format(DateTime.now()),
        );
      } catch (_) {}
    }();

    void runOnce() async {
      final syncedCount = await svc.sync(token: token);
      if (syncedCount > 0) {
        await PersistentBackgroundTrackingService.reconcileWithServer();
        if (mounted) {
          context.read<HomeBloc>().add(LoadAssignmentsRequested());
        }
      }
      timesheetSvc.sync(token: token);
      documentSvc.sync(token: token);
    }

    runOnce();
    _offlineSyncTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => runOnce());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: SessionStore.notifier,
      builder: (context, session, _) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _startOfflineSync(session.token);
        });
        _refreshReferralJobBadge(session.engineer.id);

        final tabs = [
          TodayAssignmentScreen(
              sessionToken: session.token,
              engineerName: session.engineer.fullName,
              engineerEmpCode: session.engineer.empCode),
          ActivityTimelineScreen(sessionToken: session.token),
          const ReferralsHomeScreen(),
          const DocumentUploadScreen(),
          const ProfileScreen(),
        ];

        return BlocBuilder<ShellBloc, ShellState>(
          builder: (context, state) {
            final currentIndex = state.currentIndex;

            return AppShellScope(
              index: currentIndex,
              setIndex: (idx) =>
                  context.read<ShellBloc>().add(ShellTabChanged(idx)),
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  if (currentIndex != 0) {
                    context.read<ShellBloc>().add(const ShellTabChanged(0));
                    return;
                  }
                  final bool shouldPop =
                      await showExitConfirmationDialog(context);
                  if (shouldPop) {
                    SystemNavigator.pop();
                  }
                },
                child: Scaffold(
                  body: Column(
                    children: [
                      if (_isOffline) const _NoInternetBanner(),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: KeyedSubtree(
                            key: ValueKey<int>(currentIndex),
                            child: tabs[currentIndex],
                          ),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .shadow
                              .withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      child: NavigationBarTheme(
                        data: NavigationBarThemeData(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          indicatorColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          labelTextStyle:
                              WidgetStateProperty.resolveWith((states) {
                            final screenWidth =
                                MediaQuery.sizeOf(context).width;
                            final isSelected =
                                states.contains(WidgetState.selected);
                            // Scale font dynamically based on screen width to prevent wrapping with 5 tabs
                            final baseSize = screenWidth < 360
                                ? 9.5
                                : (screenWidth < 400 ? 10.5 : 11.5);

                            return TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontSize: baseSize,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              letterSpacing:
                                  -0.5, // Tighter letter spacing to fit
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return IconThemeData(
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              );
                            }
                            return IconThemeData(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 22,
                            );
                          }),
                        ),
                        child: NavigationBar(
                          selectedIndex: currentIndex,
                          backgroundColor: Colors.transparent,
                          indicatorColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          height: 80, // slightly taller for premium feel
                          elevation: 0, // shadow provided by container
                          labelBehavior:
                              NavigationDestinationLabelBehavior.alwaysShow,
                          animationDuration: const Duration(milliseconds: 400),
                          onDestinationSelected: (idx) {
                            context.read<ShellBloc>().add(ShellTabChanged(idx));
                            if (idx == 2) {
                              unawaited(ReferralJobBadgeService.instance.markSeen(
                                engineerId: session.engineer.id,
                              ));
                            }
                          },
                          destinations: [
                            const NavigationDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard_rounded),
                              label: "Dashboard",
                            ),
                            const NavigationDestination(
                              icon: Icon(Icons.timeline_rounded),
                              selectedIcon: Icon(Icons.timeline_rounded),
                              label: "Timeline",
                            ),
                            NavigationDestination(
                              icon: ValueListenableBuilder<int>(
                                valueListenable: ReferralJobBadgeService.instance.unseenCount,
                                builder: (_, count, __) => Badge(
                                  isLabelVisible: count > 0,
                                  label: Text(count > 99 ? '99+' : '$count'),
                                  child: const Icon(Icons.volunteer_activism_outlined),
                                ),
                              ),
                              selectedIcon: ValueListenableBuilder<int>(
                                valueListenable: ReferralJobBadgeService.instance.unseenCount,
                                builder: (_, count, __) => Badge(
                                  isLabelVisible: count > 0,
                                  label: Text(count > 99 ? '99+' : '$count'),
                                  child: const Icon(Icons.volunteer_activism_rounded),
                                ),
                              ),
                              label: "Refer & Earn",
                            ),
                            NavigationDestination(
                              icon: BlocBuilder<DocumentsBloc, DocumentsState>(
                                builder: (context, docState) {
                                  final latestDocs =
                                      <String, EngineerDocument>{};
                                  for (final d in docState.documents) {
                                    if (d.documentType != 'other') {
                                      latestDocs.putIfAbsent(
                                          d.documentType, () => d);
                                    }
                                  }
                                  final dept =
                                      SessionStore.current?.engineer.department;
                                  final requiredTypes =
                                      OnboardingStatusModel.getRequiredTypesForDepartment(dept);
                                  final missing = requiredTypes
                                      .where((type) =>
                                          latestDocs[type]?.fileUrl.trim().isEmpty ?? true)
                                      .length;

                                  if (missing > 0 &&
                                      docState.status ==
                                          DocumentsStatus.loaded) {
                                    return Badge(
                                      label: Text('$missing'),
                                      backgroundColor: const Color(0xFFEF4444),
                                      child: const Icon(Icons.folder_outlined),
                                    );
                                  }
                                  return const Icon(Icons.folder_outlined);
                                },
                              ),
                              selectedIcon:
                                  BlocBuilder<DocumentsBloc, DocumentsState>(
                                builder: (context, docState) {
                                  final latestDocs =
                                      <String, EngineerDocument>{};
                                  for (final d in docState.documents) {
                                    if (d.documentType != 'other') {
                                      latestDocs.putIfAbsent(
                                          d.documentType, () => d);
                                    }
                                  }
                                  final dept =
                                      SessionStore.current?.engineer.department;
                                  final requiredTypes =
                                      OnboardingStatusModel.getRequiredTypesForDepartment(dept);
                                  final missing = requiredTypes
                                      .where((type) =>
                                          latestDocs[type]?.fileUrl.trim().isEmpty ?? true)
                                      .length;

                                  if (missing > 0 &&
                                      docState.status ==
                                          DocumentsStatus.loaded) {
                                    return Badge(
                                      label: Text('$missing'),
                                      backgroundColor: const Color(0xFFEF4444),
                                      child: const Icon(
                                          Icons.folder_shared_rounded),
                                    );
                                  }
                                  return const Icon(
                                      Icons.folder_shared_rounded);
                                },
                              ),
                              label: "Documents",
                            ),
                            const NavigationDestination(
                              icon: Icon(Icons.person_outline_rounded),
                              selectedIcon: Icon(Icons.person_rounded),
                              label: "Profile",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NoInternetBanner extends StatelessWidget {
  const _NoInternetBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 20, color: cs.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No internet connection. Live data may be unavailable; offline actions will sync when you reconnect.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
