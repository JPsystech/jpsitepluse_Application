import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/shared/models/auth_session.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/services/offline_punch_sync_service.dart";
import "package:sitepulse_engineer/core/services/offline_timesheet_sync_service.dart";
import "package:sitepulse_engineer/features/home/presentation/screens/today_assignment_screen.dart";
import "package:sitepulse_engineer/features/history/data/services/history_service.dart";
import "package:sitepulse_engineer/features/timesheet/data/services/timesheet_service.dart";
import "package:sitepulse_engineer/features/profile/presentation/screens/profile_screen.dart";
import "package:intl/intl.dart";
import "package:sitepulse_engineer/features/timeline/presentation/screens/activity_timeline_screen.dart";
import "package:sitepulse_engineer/features/timesheet/presentation/screens/timesheet_screen.dart";
import "package:sitepulse_engineer/shared/utils/dialog_utils.dart";
import "package:sitepulse_engineer/features/shell/presentation/bloc/shell_bloc.dart";
import "../../../../core/services/offline_document_sync_service.dart";
import "../../../home/presentation/bloc/home_bloc.dart";

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
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShellBloc(),
      child: const _AppShellView(),
    );
  }
}

class _AppShellView extends StatefulWidget {
  const _AppShellView();

  @override
  State<_AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<_AppShellView> {
  Timer? _offlineSyncTimer;
  String? _offlineSyncToken;

  @override
  void dispose() {
    _offlineSyncTimer?.cancel();
    super.dispose();
  }

  void _startOfflineSync(String token) {
    if (_offlineSyncToken == token && _offlineSyncTimer != null) return;
    _offlineSyncTimer?.cancel();
    _offlineSyncToken = token;
    final svc = OfflinePunchSyncService();
    final timesheetSvc = OfflineTimesheetSyncService();
    final documentSvc = OfflineDocumentSyncService();
    
    // Proactively cache timeline and timesheets on app load
    HistoryService().history(token: token).catchError((_) => null);
    TimesheetService().timesheets(
      token: token, 
      month: DateFormat('yyyy-MM').format(DateTime.now())
    ).catchError((_) => null);
    
    void runOnce() async {
      final syncedCount = await svc.sync(token: token);
      if (syncedCount > 0 && mounted) {
         context.read<HomeBloc>().add(LoadAssignmentsRequested());
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

        final tabs = [
          TodayAssignmentScreen(
              sessionToken: session.token,
              engineerName: session.engineer.fullName,
              engineerEmpCode: session.engineer.empCode),
          ActivityTimelineScreen(sessionToken: session.token),
          TimesheetScreen(
              sessionToken: session.token,
              engineerEmpCode: session.engineer.empCode),
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
                  final bool shouldPop = await showExitConfirmationDialog(context);
                  if (shouldPop) {
                    SystemNavigator.pop();
                  }
                },
                child: Scaffold(
                  body: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey<int>(currentIndex),
                      child: tabs[currentIndex],
                    ),
                  ),
                  bottomNavigationBar: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: NavigationBarTheme(
                        data: NavigationBarThemeData(
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          labelTextStyle: WidgetStateProperty.resolveWith((states) {
                            final screenWidth = MediaQuery.sizeOf(context).width;
                            final isSelected = states.contains(WidgetState.selected);
                            // Scale font dynamically based on screen width to prevent wrapping
                            final baseSize = screenWidth < 380 ? 10.0 : 12.0;
                            
                            return TextStyle(
                              color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: baseSize,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              letterSpacing: -0.5, // Tighter letter spacing to fit
                              overflow: TextOverflow.visible,
                            );
                          }),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return IconThemeData(
                                color: Theme.of(context).colorScheme.primary,
                                size: 26,
                              );
                            }
                            return IconThemeData(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 24,
                            );
                          }),
                        ),
                        child: NavigationBar(
                          selectedIndex: currentIndex,
                          backgroundColor: Colors.transparent,
                          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                          height: 80, // slightly taller for premium feel
                          elevation: 0, // shadow provided by container
                          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                          animationDuration: const Duration(milliseconds: 400),
                          onDestinationSelected: (idx) => context
                              .read<ShellBloc>()
                              .add(ShellTabChanged(idx)),
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.today_outlined),
                              selectedIcon: Icon(Icons.today_rounded),
                              label: "Today",
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.timeline_rounded),
                              selectedIcon: Icon(Icons.timeline_rounded),
                              label: "Timeline",
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.edit_note_rounded),
                              selectedIcon: Icon(Icons.edit_note_rounded),
                              label: "Work Update",
                            ),
                            NavigationDestination(
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
