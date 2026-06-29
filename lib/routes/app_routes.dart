import "package:flutter/material.dart";

import "../features/auth/login_screen.dart";
import "../features/documents/document_upload_screen.dart";
import "../features/shell/app_shell.dart";
import "../features/splash/splash_screen.dart";
import "../features/terms/terms_screen.dart";

class AppRoutes {
  static const String splash = "/splash";
  static const String login = "/login";
  static const String terms = "/terms";
  static const String app = "/app";
  static const String documents = "/documents";

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
