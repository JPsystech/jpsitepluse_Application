import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/shared/models/auth_session.dart';

const _trackingActiveKey = 'sitepulse_duty_tracking_active';
const _attendanceLogIdKey = 'sitepulse_duty_attendance_log_id';
const _backgroundSessionKey = 'sitepulse_duty_background_session';
const _minimumMovementMeters = 10;
const _androidUpdateInterval = Duration(seconds: 15);
const _stationaryHeartbeatInterval = Duration(minutes: 4);

bool _locationUploadInProgress = false;
ServiceInstance? _backgroundServiceInstance;

Future<String?> _recoverActiveAttendanceAfterConflict() async {
  try {
    final dio = await ApiClient.instance.dio;
    final response = await dio.get('/api/v1/engineer/today-assignments');
    if (response.statusCode != 200 || response.data is! Map) return null;

    final data = Map<String, dynamic>.from(response.data as Map);
    final activeAttendanceLogId =
        data['active_attendance_log_id']?.toString().trim();
    if (activeAttendanceLogId == null ||
        activeAttendanceLogId.isEmpty ||
        activeAttendanceLogId == 'offline_') {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attendanceLogIdKey, activeAttendanceLogId);
    await prefs.setBool(_trackingActiveKey, true);
    if (kDebugMode) {
      debugPrint(
        '[BackgroundService] Recovered active attendance after conflict: '
        '$activeAttendanceLogId',
      );
    }
    return activeAttendanceLogId;
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        '[BackgroundService] Attendance conflict recovery deferred: $error',
      );
    }
    return null;
  }
}

Future<void> _stopTrackingAfterAttendanceConflict() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_trackingActiveKey);
  await prefs.remove(_attendanceLogIdKey);
  await prefs.remove(_backgroundSessionKey);
  _backgroundServiceInstance?.stopSelf();
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> _sendLocationPayload(Position position) async {
  if (_locationUploadInProgress || SessionStore.current == null) return;

  _locationUploadInProgress = true;

  try {
    if ((kDebugMode || !position.isMocked) && position.accuracy <= 200) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_trackingActiveKey) ?? false)) return;
      final attendanceLogId = prefs.getString(_attendanceLogIdKey);

      final payload = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_m': position.accuracy,
        'speed_mps': position.speed,
        'heading': position.heading,
        'battery_percent': null,
        'is_charging': false,
        'is_mocked': position.isMocked,
        'attendance_log_id': attendanceLogId,
        'source': 'LIVE_BG',
        'captured_at': position.timestamp.toUtc().toIso8601String(),
      };

      final dio = await ApiClient.instance.dio;
      final response =
          await dio.post('/api/v1/engineer/live-location', data: payload);
      if (kDebugMode) {
        debugPrint(
          '[BackgroundService] Location sent successfully: '
          '${position.latitude}, ${position.longitude} '
          '(Status: ${response.statusCode})',
        );
      }
    }
  } catch (e) {
    if (e is DioException && e.response?.statusCode == 409) {
      final recoveredAttendanceLogId =
          await _recoverActiveAttendanceAfterConflict();
      if (recoveredAttendanceLogId == null) {
        await _stopTrackingAfterAttendanceConflict();
        return;
      }

      try {
        final retryPayload = Map<String, dynamic>.from(e.requestOptions.data as Map)
          ..['attendance_log_id'] = recoveredAttendanceLogId;
        final dio = await ApiClient.instance.dio;
        final response = await dio.post(
          '/api/v1/engineer/live-location',
          data: retryPayload,
        );
        if (kDebugMode) {
          debugPrint(
            '[BackgroundService] Location sent after attendance recovery '
            '(Status: ${response.statusCode})',
          );
        }
        return;
      } catch (retryError) {
        if (retryError is DioException &&
            retryError.response?.statusCode == 409) {
          await _stopTrackingAfterAttendanceConflict();
        }
        if (kDebugMode) {
          debugPrint(
            '[BackgroundService] Error retrying location after attendance '
            'recovery: $retryError',
          );
        }
        return;
      }
    }
    if (kDebugMode) {
      debugPrint('[BackgroundService] Error sending location: $e');
    }
  } finally {
    _locationUploadInProgress = false;
  }
}

LocationSettings _backgroundLocationSettings() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: _minimumMovementMeters,
      intervalDuration: _androidUpdateInterval,
    );
  }

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: _minimumMovementMeters,
      activityType: ActivityType.other,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );
  }

  return const LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: _minimumMovementMeters,
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _backgroundServiceInstance = service;

  final prefs = await SharedPreferences.getInstance();
  final trackingActive = prefs.getBool(_trackingActiveKey) ?? false;
  if (!trackingActive) {
    service.stopSelf();
    return;
  }

  // Secure storage can still be busy while the UI isolate is completing a
  // punch-in. Give it a few short retries before deciding the session is gone.
  for (var attempt = 0;
      attempt < 3 && SessionStore.current == null;
      attempt++) {
    await SessionStore.load();
    if (SessionStore.current == null && attempt < 2) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
  if (SessionStore.current == null) {
    final rawBackgroundSession = prefs.getString(_backgroundSessionKey);
    if (rawBackgroundSession != null &&
        rawBackgroundSession.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBackgroundSession);
        if (decoded is Map<String, dynamic>) {
          final session = AuthSession.fromJson(decoded);
          if (session.token.trim().isNotEmpty &&
              (session.expiresAtMs == null ||
                  DateTime.now().millisecondsSinceEpoch <
                      session.expiresAtMs!)) {
            SessionStore.current = session;
          }
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[BackgroundService] Background session snapshot invalid: $error',
          );
        }
      }
    }
  }
  if (SessionStore.current == null) {
    if (kDebugMode) {
      debugPrint(
        '[BackgroundService] Secure session unavailable after retries; '
        'service stopped without clearing the duty-tracking state.',
      );
    }
    service.stopSelf();
    return;
  }

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  StreamSubscription<Position>? positionSubscription;
  Timer? heartbeatTimer;
  service.on('stopService').listen((_) async {
    heartbeatTimer?.cancel();
    await positionSubscription?.cancel();
    service.stopSelf();
  });

  // A single balanced-accuracy stream avoids the former high-accuracy stream
  // plus a separate polling loop. The single stream requests a 15-second,
  // 10-metre cadence so short active-duty routes still have useful detail.
  positionSubscription = Geolocator.getPositionStream(
    locationSettings: _backgroundLocationSettings(),
  ).listen(
    (position) => unawaited(_sendLocationPayload(position)),
    onError: (Object error) {
      if (kDebugMode) {
        debugPrint('[BackgroundService] Stream error: $error');
      }
    },
  );

  // Create the first server row immediately. Subsequent updates stay on the
  // movement/interval-filtered stream and low-frequency heartbeat.
  unawaited(() async {
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _sendLocationPayload(initialPosition);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[BackgroundService] Initial location deferred: $error');
      }
    }
  }());

  // A low-frequency heartbeat keeps a stationary on-duty engineer from being
  // shown as interrupted without returning to the former 15-second polling.
  heartbeatTimer = Timer.periodic(_stationaryHeartbeatInterval, (_) async {
    if (_locationUploadInProgress) return;
    try {
      final heartbeatPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _sendLocationPayload(heartbeatPosition);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[BackgroundService] Heartbeat deferred: $error');
      }
    }
  });
}

class PersistentBackgroundTrackingService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> initializeService() async {
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        foregroundServiceTypes: const [AndroidForegroundType.location],
        notificationChannelId: 'sitepulse_active_shift',
        initialNotificationTitle: 'JP SitePulse - On Duty',
        initialNotificationContent: 'Location tracking active',
        foregroundServiceNotificationId: 754321,
      ),
    );
  }

  static Future<void> startTracking({
    String? attendanceLogId,
    String? projectName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (attendanceLogId != null && attendanceLogId.trim().isNotEmpty) {
      await prefs.setString(_attendanceLogIdKey, attendanceLogId.trim());
    }
    final session = SessionStore.current;
    if (session != null && session.token.trim().isNotEmpty) {
      await prefs.setString(
        _backgroundSessionKey,
        jsonEncode(session.toJson()),
      );
    }
    await prefs.setBool(_trackingActiveKey, true);

    try {
      final isRunning = await _service.isRunning().timeout(
            const Duration(seconds: 1),
            onTimeout: () => false,
          );
      if (!isRunning) {
        await _service.startService();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundService] startTracking error: $e');
      }
    }
  }

  static Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trackingActiveKey);
    await prefs.remove(_attendanceLogIdKey);
    await prefs.remove(_backgroundSessionKey);

    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }

  static Future<void> reconcileWithServer() async {
    if (SessionStore.current == null) {
      await stopTracking();
      return;
    }

    try {
      final dio = await ApiClient.instance.dio;
      final response = await dio.get('/api/v1/engineer/today-assignments');
      if (response.statusCode != 200 || response.data is! Map) return;

      final data = Map<String, dynamic>.from(response.data as Map);
      final activeAttendanceLogId =
          data['active_attendance_log_id']?.toString().trim();
      if (activeAttendanceLogId != null &&
          activeAttendanceLogId.isNotEmpty &&
          activeAttendanceLogId != 'offline_') {
        await startTracking(attendanceLogId: activeAttendanceLogId);
      } else {
        await stopTracking();
      }
    } catch (error) {
      // Preserve the current state while offline. The backend remains
      // authoritative and will return 409 if the attendance has ended.
      if (kDebugMode) {
        debugPrint('[BackgroundService] Reconciliation deferred: $error');
      }
    }
  }
}
