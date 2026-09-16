import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';
import 'package:sitepulse_engineer/core/router/navigation_service.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class NotificationRouter {
  static Future<void> handleNotificationClick(Map<String, dynamic> data) async {
    debugPrint('[NotificationRouter] Handling payload: $data');

    // Wait until NavigatorState is mounted and ready
    int attempts = 0;
    while (NavigationService.navigatorKey.currentState == null && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (NavigationService.navigatorKey.currentState == null) {
      debugPrint('[NotificationRouter] NavigatorState is not mounted after waiting.');
      return;
    }

    // Ensure session is loaded
    if (SessionStore.current == null) {
      await SessionStore.load();
    }

    final bool isLoggedIn = SessionStore.current != null;

    if (!isLoggedIn) {
      debugPrint('[NotificationRouter] User not logged in, routing to Login');
      NavigationService.navigateToAndClear(AppRoutes.login);
      return;
    }

    final String? type = data['type']?.toString().toUpperCase();
    debugPrint('[NotificationRouter] Routing for type: $type');

    switch (type) {
      case 'ASSIGNMENT':
      case 'ATTENDANCE':
      case 'SHIFT_REMINDER':
      case 'OVERDUE_PUNCH_OUT':
        NavigationService.navigateToTab(0);
        break;

      case 'DOCUMENT':
      case 'DOCUMENT_VERIFICATION':
        NavigationService.navigateTo(AppRoutes.documents);
        break;

      case 'SUBMISSION':
      case 'WORK_SUBMISSION':
      case 'TIMESHEET':
        NavigationService.navigateToTab(2);
        break;

      default:
        NavigationService.navigateToTab(0);
        break;
    }
  }
}
