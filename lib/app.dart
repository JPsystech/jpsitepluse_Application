import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sitepulse_engineer/features/notifications/presentation/bloc/notifications_bloc.dart";

import "core/router/app_routes.dart";
import "core/router/navigation_service.dart";
import "core/theme/app_theme.dart";

class SitePulseAppFoundation extends StatelessWidget {
  const SitePulseAppFoundation({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NotificationsBloc>(
          create: (_) => NotificationsBloc(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        title: "JP SitePulse",
        theme: AppTheme.light(),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
