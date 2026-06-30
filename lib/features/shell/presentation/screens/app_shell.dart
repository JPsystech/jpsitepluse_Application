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
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(15),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withAlpha(40),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: NavigationBarTheme(
                              data: NavigationBarThemeData(
                                backgroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                                indicatorColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withAlpha(40),
                                labelTextStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
                                ),
                                iconTheme: const WidgetStatePropertyAll(
                                  IconThemeData(color: Colors.white70),
                                ),
                              ),
                              child: NavigationBar(
                                selectedIndex: currentIndex,
                                height: 64,
                                elevation: 0,
                                onDestinationSelected: (idx) => context
                                    .read<ShellBloc>()
                                    .add(ShellTabChanged(idx)),
                                destinations: [
                                  NavigationDestination(
                                    icon: const Icon(Icons.today_outlined),
                                    selectedIcon: Icon(Icons.today,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    label: "Today",
                                  ),
                                  NavigationDestination(
                                    icon: const Icon(Icons.timeline),
                                    selectedIcon: Icon(Icons.timeline,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    label: "Timeline",
                                  ),
                                  NavigationDestination(
                                    icon: const Icon(Icons.edit_note),
                                    selectedIcon: Icon(Icons.edit_note,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    label: "Work Update",
                                  ),
                                  NavigationDestination(
                                    icon: const Icon(Icons.person_outline),
                                    selectedIcon: Icon(Icons.person,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    label: "Profile",
                                  ),
                                ],
                              ),
                            ),
                          ),
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
