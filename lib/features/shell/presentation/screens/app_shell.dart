import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/shared/models/auth_session.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/services/offline_punch_sync_service.dart";
import "package:sitepulse_engineer/features/home/presentation/screens/today_assignment_screen.dart";
import "package:sitepulse_engineer/features/profile/presentation/screens/profile_screen.dart";
import "package:sitepulse_engineer/features/timeline/presentation/screens/activity_timeline_screen.dart";
import "package:sitepulse_engineer/features/timesheet/presentation/screens/timesheet_screen.dart";

import "package:sitepulse_engineer/features/shell/presentation/bloc/shell_bloc.dart";

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
    void runOnce() {
      svc.sync(token: token);
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
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  if (currentIndex != 0) {
                    context.read<ShellBloc>().add(const ShellTabChanged(0));
                    return;
                  }
                  SystemNavigator.pop();
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
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
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
                            if (states.contains(WidgetState.selected)) {
                              return TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              );
                            }
                            return TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
