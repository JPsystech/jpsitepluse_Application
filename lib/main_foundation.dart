import "package:flutter/material.dart";

import "routes/app_routes.dart";
import "theme/app_theme.dart";

void main() {
  runApp(const SitePulseAppFoundation());
}

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

