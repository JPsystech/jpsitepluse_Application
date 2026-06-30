import "package:flutter/material.dart";

import "core/router/app_routes.dart";
import "core/theme/app_theme.dart";

class SitePulseAppFoundation extends StatelessWidget {
  const SitePulseAppFoundation({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "JP SitePulse",
      theme: AppTheme.light(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
