import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/router/navigation_service.dart';
import 'package:sitepulse_engineer/core/router/notification_router.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/services/location_request_response_service.dart';
import 'package:sitepulse_engineer/core/services/shift_action_service.dart';
import 'package:sitepulse_engineer/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:sitepulse_engineer/features/notifications/data/services/notification_center_service.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'sitepulse_alerts';
  static const String _channelName = 'SitePulse Alerts';
  static const String _channelDesc =
      'Important notifications, shift reminders, and project updates.';
  static const String _lastTokenKey = 'sitepulse_last_synced_fcm_token';
  static const String _activeShiftChannelId = 'sitepulse_active_shift';

  bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // The foreground tracking service owns notification id 754321. Creating
  // its channel here guarantees the channel exists before a shift starts,
  // while avoiding a second notification that can replace the service's own.
  static const AndroidNotificationChannel _activeShiftChannel =
      AndroidNotificationChannel(
    _activeShiftChannelId,
    'Active Shift Tracking',
    description: 'Visible while on-duty location tracking is active.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Setup Notification Channel for Android
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_channel);
        await androidImplementation.createNotificationChannel(_activeShiftChannel);
        // Firebase's permission API does not consistently surface the Android
        // 13+ POST_NOTIFICATIONS prompt on every device/OEM. Request it from
        // the Android notifications implementation too, so FCM alerts (such
        // as a geofence exit) are not silently suppressed on a fresh install.
        await androidImplementation.requestNotificationsPermission();
      }

      // Initialize Flutter Local Notifications
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_notification');
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      // Request notification permissions
      await _requestPermissions();

      // Setup listeners
      _setupForegroundListener();
      _setupNotificationOpenListeners();
      _setupTokenRefreshListener();

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully');
    } catch (e, stack) {
      debugPrint('[NotificationService] Initialization error: $e\n$stack');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[NotificationService] Error requesting permission: $e');
    }
  }

  Future<void> showIncomingNotification(RemoteMessage message) async {
    final notifId = (message.data['notification_id'] ??
            message.data['id'] ??
            message.data['campaign_id'] ??
            '')
        .toString()
        .trim();
    if (notifId.isNotEmpty) {
      NotificationCenterService().markAsDelivered(notifId);
    }

    await _showLocalNotification(message);
    try {
      final ctx = NavigationService.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.read<NotificationsBloc>().add(
              const LoadNotificationsRequested(silent: true),
            );
      }
    } catch (_) {}
  }

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] Received: ${message.notification?.title} - ${message.notification?.body}');
      final type = message.data['type']?.toString().toUpperCase();
      if (type == 'LOCATION_REQUEST') {
        final requestId = (message.data['request_id'] ?? message.data['requestId'] ?? '').toString();
        LocationRequestResponseService.handleLocationRequest(requestId);
        return;
      }

      if (type == 'DEVICE_RESET' || type == 'FORCE_LOGOUT') {
        // Do not display reset notification
        return;
      }

      showIncomingNotification(message);
    });
  }

  void _setupNotificationOpenListeners() {
    // App opened from background state by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM OpenedApp] User tapped notification: ${message.data}');
      final payloadMap = Map<String, dynamic>.from(message.data);
      if (message.notification?.title != null && !payloadMap.containsKey('title')) {
        payloadMap['title'] = message.notification!.title;
      }
      if (message.notification?.body != null && !payloadMap.containsKey('body')) {
        payloadMap['body'] = message.notification!.body;
      }
      NotificationRouter.handleNotificationClick(payloadMap);
    });

    // App launched from terminated state by tapping notification
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FCM InitialMessage] App launched from notification: ${message.data}');
        final payloadMap = Map<String, dynamic>.from(message.data);
        if (message.notification?.title != null && !payloadMap.containsKey('title')) {
          payloadMap['title'] = message.notification!.title;
        }
        if (message.notification?.body != null && !payloadMap.containsKey('body')) {
          payloadMap['body'] = message.notification!.body;
        }
        Future.delayed(const Duration(milliseconds: 600), () {
          NotificationRouter.handleNotificationClick(payloadMap);
        });
      }
    });
  }

  void _setupTokenRefreshListener() {
    _fcm.onTokenRefresh.listen((String newToken) {
      debugPrint('[FCM Token] Token refreshed');
      syncToken(newToken);
    });
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.actionId == 'punch_out') {
      ShiftActionService.requestPunchOut();
      NavigationService.navigateToTab(0);
      return;
    }
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        NotificationRouter.handleNotificationClick(data);
      } catch (e) {
        debugPrint('[NotificationService] Failed to parse local notification payload: $e');
      }
    }
  }

  Future<void> showActiveShiftNotification({String? projectName}) async {
    if (!Platform.isAndroid) return;

    final bodyText = (projectName != null && projectName.trim().isNotEmpty)
        ? 'Project: ${projectName.trim()} • Location tracking active'
        : 'On-duty location tracking active';

    const details = AndroidNotificationDetails(
      _activeShiftChannelId,
      'Active Shift',
      channelDescription: 'On-duty location tracking and shift actions.',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@drawable/ic_notification',
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.service,
    );

    await _localNotifications.show(
      754321,
      'JP SitePulse - On Duty',
      bodyText,
      const NotificationDetails(android: details),
      payload: jsonEncode({'type': 'SHIFT_PUNCH_OUT'}),
    );
  }

  Future<void> cancelActiveShiftNotification() async {
    await _localNotifications.cancel(754321);
  }

  Future<void> showPunchInConfirmation() async {
    const details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon:
          DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
      color: Color(0xFF0D47A1),
    );

    await _localNotifications.show(
      754320,
      'Punch in successful',
      'You are now on duty. Location tracking is active.',
      const NotificationDetails(android: details),
      payload: jsonEncode({'type': 'ATTENDANCE'}),
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'JP SitePulse';
    final body = notification?.body ?? message.data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
      color: const Color(0xFF0D47A1),
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final payloadMap = Map<String, dynamic>.from(message.data);
    if (!payloadMap.containsKey('title') || (payloadMap['title'] as String?)?.isEmpty == true) {
      payloadMap['title'] = title;
    }
    if (!payloadMap.containsKey('body') || (payloadMap['body'] as String?)?.isEmpty == true) {
      payloadMap['body'] = body;
    }
    final String payload = jsonEncode(payloadMap);

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> syncToken([String? token]) async {
    try {
      final session = SessionStore.current;
      if (session == null || session.token.trim().isEmpty) {
        debugPrint('[NotificationService] User not logged in, skipping token sync');
        return;
      }

      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken == null || fcmToken.trim().isEmpty) {
        debugPrint('[NotificationService] FCM token is null or empty');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastToken = prefs.getString(_lastTokenKey);
      if (lastToken == fcmToken) {
        debugPrint('[NotificationService] FCM token is already synced');
        return;
      }

      final deviceId = await SessionStore.getDeviceId();
      final client = await ApiClient.instance.dio;

      final response = await client.post(
        '/api/v1/engineer/fcm-token',
        data: {
          'fcm_token': fcmToken,
          'device_id': deviceId,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${session.token}'},
        ),
      );

      if (response.statusCode == 200) {
        await prefs.setString(_lastTokenKey, fcmToken);
        debugPrint('[NotificationService] FCM token successfully registered with backend');
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to sync FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString(_lastTokenKey) ?? await _fcm.getToken();
      final session = SessionStore.current;

      if (session != null && fcmToken != null && fcmToken.isNotEmpty) {
        final client = await ApiClient.instance.dio;
        await client.delete(
          '/api/v1/engineer/fcm-token',
          queryParameters: {'fcm_token': fcmToken},
          options: Options(
            headers: {'Authorization': 'Bearer ${session.token}'},
          ),
        );
        debugPrint('[NotificationService] FCM token unregistered from backend');
      }

      await prefs.remove(_lastTokenKey);
    } catch (e) {
      debugPrint('[NotificationService] Failed to unregister FCM token: $e');
    }
  }
}
