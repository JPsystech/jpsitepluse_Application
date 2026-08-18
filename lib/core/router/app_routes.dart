import "package:flutter/material.dart";

import "package:sitepulse_engineer/features/auth/presentation/screens/login_screen.dart";
import "package:sitepulse_engineer/features/documents/presentation/screens/document_upload_screen.dart";
import "package:sitepulse_engineer/features/shell/presentation/screens/app_shell.dart";
import "package:sitepulse_engineer/features/splash/presentation/screens/splash_screen.dart";
import "package:sitepulse_engineer/features/terms/presentation/screens/terms_screen.dart";
import "package:sitepulse_engineer/features/auth/presentation/screens/mpin_setup_screen.dart";
import "package:sitepulse_engineer/features/auth/presentation/screens/change_mpin_screen.dart";
import "package:sitepulse_engineer/features/auth/presentation/screens/mpin_otp_request_screen.dart";
import "package:sitepulse_engineer/features/auth/presentation/screens/mpin_otp_screen.dart";

class AppRoutes {
  static const String splash = "/splash";
  static const String login = "/login";
  static const String terms = "/terms";
  static const String app = "/app";
  static const String documents = "/documents";
  static const String mpinSetup = "/mpin-setup";
  static const String changeMpin = "/change-mpin";
  static const String mpinOtpRequest = "/mpin-otp-request";
  static const String mpinOtpVerify = "/mpin-otp-verify";

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
      case changeMpin:
        return MaterialPageRoute(builder: (_) => const ChangeMpinScreen());
      case mpinOtpRequest:
        return MaterialPageRoute(builder: (_) => const MpinOtpRequestScreen());
      case mpinOtpVerify:
        if (settings.arguments is Map) {
          final args = settings.arguments as Map;
          return MaterialPageRoute(
            builder: (_) => MpinOtpScreen(
              vendorCode: args['vendorCode'] as String,
              empCode: args['empCode'] as String,
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case mpinSetup:
        if (settings.arguments is bool) {
          final bool isServerMpinSet = settings.arguments as bool;
          return MaterialPageRoute(builder: (_) => MpinSetupScreen(isServerMpinSet: isServerMpinSet));
        } else if (settings.arguments is Map) {
          final args = settings.arguments as Map;
          final bool isServerMpinSet = args['isServerMpinSet'] as bool? ?? false;
          final bool isResetMode = args['isResetMode'] as bool? ?? false;
          final String? resetToken = args['resetToken'] as String?;
          return MaterialPageRoute(builder: (_) => MpinSetupScreen(isServerMpinSet: isServerMpinSet, isResetMode: isResetMode, resetToken: resetToken));
        } else {
          return MaterialPageRoute(builder: (_) => const MpinSetupScreen());
        }

      default:
        // Fallback: redirect to login screen instead of showing an error
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
