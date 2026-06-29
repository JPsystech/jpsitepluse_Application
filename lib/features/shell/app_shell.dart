import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/session_store.dart";
import "../../routes/app_routes.dart";
import "../../services/offline_punch_sync_service.dart";
import "../home/today_assignment_screen.dart";
import "../profile/profile_screen.dart";
import "../timeline/activity_timeline_screen.dart";
import "../timesheet/timesheet_screen.dart";
import "../../theme/app_theme.dart";

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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int currentIndex = 0;
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
    _offlineSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) => runOnce());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SessionStore.notifier,
      builder: (context, session, _) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _startOfflineSync(session.token);
        });

        final tabs = [
          TodayAssignmentScreen(sessionToken: session.token, engineerName: session.engineer.fullName, engineerEmpCode: session.engineer.empCode),
          ActivityTimelineScreen(sessionToken: session.token),
          TimesheetScreen(sessionToken: session.token, engineerEmpCode: session.engineer.empCode),
          const ProfileScreen(),
        ];

        return AppShellScope(
          index: currentIndex,
          setIndex: (idx) => setState(() => currentIndex = idx),
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (currentIndex != 0) {
                setState(() => currentIndex = 0);
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
                      color: AppTheme.navy.withAlpha(15),
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
                        color: AppTheme.navy,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.navy.withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: NavigationBarTheme(
                          data: NavigationBarThemeData(
                            backgroundColor: AppTheme.navy,
                            indicatorColor: AppTheme.sky.withAlpha(40),
                            labelTextStyle: const WidgetStatePropertyAll(
                              TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            iconTheme: const WidgetStatePropertyAll(
                              IconThemeData(color: Colors.white70),
                            ),
                          ),
                          child: NavigationBar(
                            selectedIndex: currentIndex,
                            height: 64,
                            elevation: 0,
                            onDestinationSelected: (idx) => setState(() => currentIndex = idx),
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.today_outlined),
                                selectedIcon: Icon(Icons.today, color: AppTheme.sky),
                                label: "Today",
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.timeline),
                                selectedIcon: Icon(Icons.timeline, color: AppTheme.sky),
                                label: "Timeline",
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.edit_note),
                                selectedIcon: Icon(Icons.edit_note, color: AppTheme.sky),
                                label: "Work Update",
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.person_outline),
                                selectedIcon: Icon(Icons.person, color: AppTheme.sky),
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
  }
}
