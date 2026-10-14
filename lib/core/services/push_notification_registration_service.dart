import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:sitepulse_engineer/core/services/location_request_response_service.dart';
import 'package:sitepulse_engineer/core/services/live_location_tracking_service.dart';
import 'package:sitepulse_engineer/core/services/notification_service.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await PushNotificationRegistrationService.initializeFirebase();
  await PushNotificationRegistrationService.handleRemoteMessage(message);
}

class PushNotificationRegistrationService {
  PushNotificationRegistrationService._();

  static bool _firebaseReady = false;
  static bool _refreshListenerAttached = false;

  static Future<void> initializeFirebase() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _firebaseReady = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase initialization skipped: $e');
      }
    }
  }

  static Future<void> registerForCurrentSession() async {
    final session = SessionStore.current;
    if (session == null || session.token.trim().isEmpty) return;

    await initializeFirebase();
    if (!_firebaseReady) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _sendTokenToBackend(token);
      }

      if (!_refreshListenerAttached) {
        _refreshListenerAttached = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((freshToken) async {
          await _sendTokenToBackend(freshToken);
        });
        FirebaseMessaging.onMessage.listen((message) async {
          await handleRemoteMessage(message);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token registration skipped: $e');
      }
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    if (SessionStore.current == null || token.trim().isEmpty) return;

    try {
      final dio = await ApiClient.instance.dio;
      final deviceId = await SessionStore.getDeviceId();
      await dio.post(
        '/api/v1/engineer/fcm-token',
        data: {
          'fcm_token': token.trim(),
          'device_id': deviceId,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        },
      );
      if (kDebugMode) {
        debugPrint('FCM token registered with backend.');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to register FCM token: ${e.response?.data ?? e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to register FCM token: $e');
      }
    }
  }

  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    final type = (message.data['type'] ?? '').toString().trim().toUpperCase();
    if (type == 'LOCATION_REQUEST') {
      final requestId = (message.data['request_id'] ?? message.data['requestId'] ?? '').toString().trim();
      if (requestId.isEmpty) return;
      await LocationRequestResponseService.handleLocationRequest(requestId);
      return;
    }

    if (type == 'TRANSIT_MODE_UPDATE') {
      final isTransit = (message.data['is_transit'] ?? '').toString().trim().toLowerCase() == 'true';
      await LiveLocationTrackingService.instance.setTransitMode(isTransit);
      return;
    }

    if (type == 'DEVICE_RESET' || type == 'FORCE_LOGOUT') {
      // Do not show reset notification to user
      return;
    }

    // For other notification types (assignments, reminders, etc.)
    try {
      await NotificationService.instance.showIncomingNotification(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error showing incoming notification: $e');
      }
    }
  }
}
