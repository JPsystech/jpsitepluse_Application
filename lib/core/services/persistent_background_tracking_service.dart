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
const _pendingLocationsKey = 'sitepulse_pending_live_locations_v1';
const _maxPendingLocations = 5000;
const _locationUploadBatchSize = 200;
const _minimumMovementMeters = 10;
const _androidUpdateInterval = Duration(seconds: 15);
const _stationaryHeartbeatInterval = Duration(minutes: 4);

bool _locationUploadInProgress = false;
ServiceInstance? _backgroundServiceInstance;
Future<void> _queueMutation = Future<void>.value();

Future<T> _withQueueLock<T>(Future<T> Function() action) async {
  final previous = _queueMutation;
  final completer = Completer<void>();
  _queueMutation = completer.future;
  await previous;
  try {
    return await action();
  } finally {
    completer.complete();
  }
}

Future<List<Map<String, dynamic>>> _readPendingLocations(
  SharedPreferences prefs,
) async {
  final raw = prefs.getString(_pendingLocationsKey);
  if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[BackgroundService] Pending location queue invalid: $error');
    }
    return <Map<String, dynamic>>[];
  }
}

Future<void> _writePendingLocations(
  SharedPreferences prefs,
  List<Map<String, dynamic>> locations,
) async {
  if (locations.isEmpty) {
    await prefs.remove(_pendingLocationsKey);
  } else {
    await prefs.setString(_pendingLocationsKey, jsonEncode(locations));
  }
}

Future<void> _enqueueLocation(Map<String, dynamic> payload) async {
  await _withQueueLock(() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await _readPendingLocations(prefs)..add(payload);
    if (pending.length > _maxPendingLocations) {
      pending.removeRange(0, pending.length - _maxPendingLocations);
    }
    await _writePendingLocations(prefs, pending);
  });
}

Future<void> _retainLocationsForAttendance(String attendanceLogId) async {
  await _withQueueLock(() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await _readPendingLocations(prefs);
    final matching = pending.where((location) {
      final queuedId = location['attendance_log_id']?.toString().trim();
      return queuedId == null ||
          queuedId.isEmpty ||
          queuedId == attendanceLogId;
    }).map((location) {
      if (location['attendance_log_id'] == null) {
        location['attendance_log_id'] = attendanceLogId;
      }
      return location;
    }).toList();
    await _writePendingLocations(prefs, matching);
  });
}

Future<void> _flushPendingLocations() async {
  if (_locationUploadInProgress || SessionStore.current == null) return;
  _locationUploadInProgress = true;

  try {
    final prefs = await SharedPreferences.getInstance();
    while (prefs.getBool(_trackingActiveKey) ?? false) {
      final pending = await _withQueueLock(
        () => _readPendingLocations(prefs),
      );
      if (pending.isEmpty) return;

      final count = pending.length > _locationUploadBatchSize
          ? _locationUploadBatchSize
          : pending.length;
      final batch = pending.take(count).toList();
      final dio = await ApiClient.instance.dio;
      await dio.post(
        '/api/v1/engineer/live-locations/batch',
        data: <String, dynamic>{'locations': batch},
      );

      // Delete only points acknowledged by the server. Newer points, if any,
      // remain at the end of the durable queue.
      final latestPending = await _withQueueLock(() async {
        final locations = await _readPendingLocations(prefs);
        final removeCount = count > locations.length ? locations.length : count;
        locations.removeRange(0, removeCount);
        await _writePendingLocations(prefs, locations);
        return locations;
      });

      if (kDebugMode) {
        debugPrint(
          '[BackgroundService] Uploaded $count queued locations; '
          '${latestPending.length} remaining',
        );
      }
    }
  } on DioException catch (error) {
    if (error.response?.statusCode == 409) {
      final recoveredAttendanceLogId =
          await _recoverActiveAttendanceAfterConflict();
      if (recoveredAttendanceLogId == null) {
        await _stopTrackingAfterAttendanceConflict();
      }
    }
    if (kDebugMode) {
      debugPrint('[BackgroundService] Queued location upload deferred: $error');
    }
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[BackgroundService] Queued location upload deferred: $error');
    }
  } finally {
    _locationUploadInProgress = false;
  }
}

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

      // Persist before attempting the network request so a connection loss,
      // process restart, or app backgrounding cannot discard this point.
      await _enqueueLocation(payload);
      await _flushPendingLocations();
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[BackgroundService] Error queueing location: $e');
    }
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

  // Resume any upload interrupted by an earlier loss of connectivity or
  // background-service restart.
  unawaited(_flushPendingLocations());

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
      final normalizedAttendanceLogId = attendanceLogId.trim();
      await prefs.setString(_attendanceLogIdKey, normalizedAttendanceLogId);
      // A previous completed shift cannot accept more points. Keep only the
      // durable points belonging to the attendance session being started.
      await _retainLocationsForAttendance(normalizedAttendanceLogId);
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
