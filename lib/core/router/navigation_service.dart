import 'package:flutter/material.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Future<T?>? navigateTo<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState?.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  static Future<T?>? navigateToAndClear<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState?.pushNamedAndRemoveUntil<T>(
      routeName,
      (_) => false,
      arguments: arguments,
    );
  }

  static Future<T?>? navigateToTab<T extends Object?>(int tabIndex) {
    return navigatorKey.currentState?.pushNamedAndRemoveUntil<T>(
      AppRoutes.app,
      (_) => false,
      arguments: {'tabIndex': tabIndex},
    );
  }
}
