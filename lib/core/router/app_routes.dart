import "package:flutter/material.dart";

import "package:sitepulse_engineer/features/auth/presentation/screens/login_screen.dart";
import "package:sitepulse_engineer/features/documents/presentation/screens/document_upload_screen.dart";
import "package:sitepulse_engineer/features/shell/presentation/screens/app_shell.dart";
import "package:sitepulse_engineer/features/splash/presentation/screens/splash_screen.dart";
import "package:sitepulse_engineer/features/terms/presentation/screens/terms_screen.dart";
import "package:sitepulse_engineer/features/auth/presentation/screens/mpin_setup_screen.dart";
import "package:sitepulse_engineer/features/auth/presentation/screens/mpin_unlock_screen.dart";

class AppRoutes {
  static const String splash = "/splash";
  static const String login = "/login";
  static const String terms = "/terms";
  static const String app = "/app";
  static const String documents = "/documents";
  static const String mpinSetup = "/mpin-setup";
  static const String mpinUnlock = "/mpin-unlock";

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case terms:
        return MaterialPageRoute(builder: (_) => const TermsScreen());
      case app:
        return MaterialPageRoute(builder: (_) => const AppShell());
      case documents:
        return MaterialPageRoute(builder: (_) => const DocumentUploadScreen());
      case mpinSetup:
        return MaterialPageRoute(builder: (_) => const MpinSetupScreen());
      case mpinUnlock:
        return MaterialPageRoute(builder: (_) => const MpinUnlockScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Not Found")),
            body: const Center(child: Text("Route not found")),
          ),
        );
    }
  }
}
