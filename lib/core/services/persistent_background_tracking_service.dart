import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/storage/encrypted_file_store.dart';
import 'package:sitepulse_engineer/core/services/mobile_policy_service.dart';

const _trackingActiveKey = 'sitepulse_duty_tracking_active';
const _attendanceLogIdKey = 'sitepulse_duty_attendance_log_id';
const _backgroundSessionKey = 'sitepulse_duty_background_session';
const _pendingLocationsKey = 'sitepulse_pending_live_locations_v1';
const _pendingTrackingEventsKey = 'sitepulse_pending_tracking_events_v1';
const _trackingEventLastReportedPrefix = 'sitepulse_tracking_event_last_';
const _maxPendingLocations = 5000;
const _maxPendingTrackingEvents = 500;
const _locationUploadBatchSize = 200;
const _trackingEventUploadBatchSize = 100;
// Three minutes leaves room for a slow GPS fix and network retry before the
// server declares tracking interrupted, without high-frequency polling.
const _batteryReadInterval = Duration(minutes: 2);
const _deviceHealthChannel = MethodChannel('com.jpsystech.sitepluse/device_health');

bool _locationUploadInProgress = false;
bool _trackingEventUploadInProgress = false;
ServiceInstance? _backgroundServiceInstance;
Future<void> _queueMutation = Future<void>.value();
int? _lastBatteryPercent;
bool _lastBatteryIsCharging = false;
DateTime? _lastBatteryReadAt;

Future<({int? percent, bool isCharging})> _readBatteryStatus() async {
  final now = DateTime.now();
  if (_lastBatteryReadAt != null &&
      now.difference(_lastBatteryReadAt!) < _batteryReadInterval) {
    return (percent: _lastBatteryPercent, isCharging: _lastBatteryIsCharging);
  }

  try {
    final battery = Battery();
    _lastBatteryPercent = await battery.batteryLevel;
    final state = await battery.batteryState;
    _lastBatteryIsCharging =
        state == BatteryState.charging || state == BatteryState.full;
    _lastBatteryReadAt = now;
  } catch (_) {
    // Battery information is optional; location tracking must continue when
    // the platform does not expose it in a background isolate.
  }
  return (percent: _lastBatteryPercent, isCharging: _lastBatteryIsCharging);
}

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
  final raw = await _readEncryptedOrLegacy(prefs, _pendingLocationsKey);
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
    await EncryptedFileStore.delete(_pendingLocationsKey);
    await prefs.remove(_pendingLocationsKey);
  } else {
    await _writeEncryptedAndClearLegacy(
      prefs,
      _pendingLocationsKey,
      jsonEncode(locations),
    );
  }
}

Future<List<Map<String, dynamic>>> _readPendingTrackingEvents(
  SharedPreferences prefs,
) async {
  final raw = await _readEncryptedOrLegacy(prefs, _pendingTrackingEventsKey);
  if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

Future<void> _writePendingTrackingEvents(
  SharedPreferences prefs,
  List<Map<String, dynamic>> events,
) async {
  if (events.isEmpty) {
    await EncryptedFileStore.delete(_pendingTrackingEventsKey);
    await prefs.remove(_pendingTrackingEventsKey);
  } else {
    await _writeEncryptedAndClearLegacy(
      prefs,
      _pendingTrackingEventsKey,
      jsonEncode(events),
    );
  }
}

Future<String?> _readEncryptedOrLegacy(
  SharedPreferences prefs,
  String key,
) async {
  final encrypted = await EncryptedFileStore.read(key);
  if (encrypted != null) return encrypted;
  final legacy = prefs.getString(key);
  if (legacy != null) {
    await EncryptedFileStore.write(key, legacy);
    await prefs.remove(key);
  }
  return legacy;
}

Future<void> _writeEncryptedAndClearLegacy(
  SharedPreferences prefs,
  String key,
  String value,
) async {
  await EncryptedFileStore.write(key, value);
  await prefs.remove(key);
}

String _trackingPlatform() {
  if (defaultTargetPlatform == TargetPlatform.android) return 'android';
  if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
  return defaultTargetPlatform.name;
}

/// Android reports whether the app is exempt from the system battery
/// optimizer. iOS intentionally has no equivalent public API, so it is not
/// inferred or reported there.
Future<void> _recordBatteryOptimizationStatus({String? attendanceLogId}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final isExempt = await _deviceHealthChannel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    if (isExempt == false) {
      await _recordTrackingHealthEvent(
        'BATTERY_OPTIMIZATION_RESTRICTED',
        attendanceLogId: attendanceLogId,
        details:
            'Android battery optimization is enabled for this app and may delay background tracking.',
      );
    }
  } on PlatformException catch (error) {
    if (kDebugMode) {
      debugPrint('[BackgroundService] Battery optimization check failed: $error');
    }
  }
}

Future<void> _recordTrackingHealthEvent(
  String eventType, {
  String? attendanceLogId,
  String? details,
  bool throttle = true,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final attendanceId = attendanceLogId ?? prefs.getString(_attendanceLogIdKey);
  if (attendanceId == null || attendanceId.trim().isEmpty) return;

  final now = DateTime.now().toUtc();
  final throttleKey = '$_trackingEventLastReportedPrefix$eventType';
  if (throttle) {
    final lastMilliseconds = prefs.getInt(throttleKey);
    if (lastMilliseconds != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastMilliseconds, isUtc: true)).inMinutes < 5) {
      return;
    }
    await prefs.setInt(throttleKey, now.millisecondsSinceEpoch);
  }

  await _withQueueLock(() async {
    final pending = await _readPendingTrackingEvents(prefs)
      ..add(<String, dynamic>{
        'attendance_log_id': attendanceId,
        'event_type': eventType,
        'occurred_at': now.toIso8601String(),
        'details': details,
        'platform': _trackingPlatform(),
      });
    if (pending.length > _maxPendingTrackingEvents) {
      pending.removeRange(0, pending.length - _maxPendingTrackingEvents);
    }
    await _writePendingTrackingEvents(prefs, pending);
  });
  // Health events must be sent independently of a successful location
  // upload. For example, GPS being disabled prevents further location points.
  unawaited(_flushTrackingHealthEvents());
}

Future<void> _flushTrackingHealthEvents() async {
  if (_trackingEventUploadInProgress || SessionStore.current == null) return;
  _trackingEventUploadInProgress = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    while (true) {
      final pending = await _withQueueLock(() => _readPendingTrackingEvents(prefs));
      if (pending.isEmpty) return;
      final count = pending.length > _trackingEventUploadBatchSize
          ? _trackingEventUploadBatchSize
          : pending.length;
      await (await ApiClient.instance.dio).post(
        '/api/v1/engineer/tracking-events/batch',
        data: <String, dynamic>{'events': pending.take(count).toList()},
      );
      await _withQueueLock(() async {
        final latest = await _readPendingTrackingEvents(prefs);
        latest.removeRange(0, count > latest.length ? latest.length : count);
        await _writePendingTrackingEvents(prefs, latest);
      });
    }
  } catch (error) {
    if (kDebugMode) debugPrint('[BackgroundService] Tracking health upload deferred: $error');
  } finally {
    _trackingEventUploadInProgress = false;
  }
}

Future<void> _recordLocationReadinessIssue({String? attendanceLogId}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    await _recordTrackingHealthEvent('GPS_DISABLED', attendanceLogId: attendanceLogId);
    return;
  }
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    await _recordTrackingHealthEvent('LOCATION_PERMISSION_DENIED', attendanceLogId: attendanceLogId);
  } else if (defaultTargetPlatform == TargetPlatform.iOS && permission != LocationPermission.always) {
    await _recordTrackingHealthEvent('BACKGROUND_PERMISSION_MISSING', attendanceLogId: attendanceLogId);
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
      unawaited(_flushTrackingHealthEvents());

      if (kDebugMode) {
        debugPrint(
          '[BackgroundService] Uploaded $count queued locations; '
          '${latestPending.length} remaining',
        );
      }
    }
  } on DioException catch (error) {
    final statusCode = error.response?.statusCode;
    await _recordTrackingHealthEvent(
      statusCode == 401 || statusCode == 403
          ? 'AUTH_SESSION_EXPIRED'
          : statusCode == null
              ? 'NETWORK_OFFLINE'
              : 'LOCATION_UPLOAD_FAILED',
      details: statusCode == null ? 'Location upload could not reach the server.' : 'Location upload returned HTTP $statusCode.',
    );
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
  await _recordTrackingHealthEvent(
    'TRACKING_STOPPED',
    attendanceLogId: prefs.getString(_attendanceLogIdKey),
    details: 'Tracking stopped because the attendance session is no longer active.',
    throttle: false,
  );
  await _flushTrackingHealthEvents();
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
    if (position.accuracy > 200) {
      await _recordTrackingHealthEvent(
        'LOCATION_ACCURACY_TOO_LOW',
        details: 'Location accuracy was above 200 metres.',
      );
      return;
    }
    if (kDebugMode || !position.isMocked) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_trackingActiveKey) ?? false)) return;
      final attendanceLogId = prefs.getString(_attendanceLogIdKey);
      final battery = await _readBatteryStatus();

      final payload = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_m': position.accuracy,
        'speed_mps': position.speed,
        'heading': position.heading,
        'battery_percent': battery.percent,
        'is_charging': battery.isCharging,
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
    await _recordLocationReadinessIssue();
    await _recordTrackingHealthEvent(
      'LOCATION_STREAM_ERROR',
      details: 'Unable to queue a location update.',
    );
    if (kDebugMode) {
      debugPrint('[BackgroundService] Error queueing location: $e');
    }
  }
}

LocationSettings _backgroundLocationSettings() {
  final policy = MobilePolicyService.current;
  final updateInterval = Duration(seconds: policy.trackingUpdateIntervalSeconds);
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: policy.trackingMinMovementM,
      intervalDuration: updateInterval,
    );
  }

  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: policy.trackingMinMovementM,
      activityType: ActivityType.other,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );
  }

  return LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: policy.trackingMinMovementM,
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _backgroundServiceInstance = service;

  final prefs = await SharedPreferences.getInstance();
  await MobilePolicyService.loadCached();
  final trackingActive = prefs.getBool(_trackingActiveKey) ?? false;
  if (!trackingActive) {
    service.stopSelf();
    return;
  }
  await _recordLocationReadinessIssue(
    attendanceLogId: prefs.getString(_attendanceLogIdKey),
  );

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
  // Older app versions kept a duplicate token in SharedPreferences so the
  // background isolate could recover it. The primary secure SessionStore is
  // now retried above; remove any legacy plaintext snapshot on startup.
  await prefs.remove(_backgroundSessionKey);

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
  unawaited(_flushTrackingHealthEvents());

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
  Timer? readinessCheckTimer;
  service.on('stopService').listen((_) async {
    heartbeatTimer?.cancel();
    readinessCheckTimer?.cancel();
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
      unawaited(_recordLocationReadinessIssue());
      unawaited(_recordTrackingHealthEvent(
        'LOCATION_STREAM_ERROR',
        details: 'The operating system location stream returned an error.',
      ));
      if (kDebugMode) {
        debugPrint('[BackgroundService] Stream error: $error');
      }
    },
  );

  // This checks the OS location setting and permission only; it does not ask
  // for a GPS position. It gives us a bounded detection time when Android
  // silently stops the location stream after the user disables Location.
  readinessCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    unawaited(_recordLocationReadinessIssue());
  });

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
      await _recordLocationReadinessIssue();
      await _recordTrackingHealthEvent(
        'LOCATION_STREAM_ERROR',
        details: 'Unable to get the initial location fix.',
      );
      if (kDebugMode) {
        debugPrint('[BackgroundService] Initial location deferred: $error');
      }
    }
  }());

  // A low-frequency heartbeat keeps a stationary on-duty engineer from being
  // shown as interrupted without returning to the former 15-second polling.
  heartbeatTimer = Timer.periodic(
    Duration(seconds: MobilePolicyService.current.trackingStationaryHeartbeatSeconds),
    (_) async {
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
        await _recordLocationReadinessIssue();
        await _recordTrackingHealthEvent(
          'LOCATION_STREAM_ERROR',
          details: 'Unable to get the stationary tracking heartbeat.',
        );
        if (kDebugMode) {
          debugPrint('[BackgroundService] Heartbeat deferred: $error');
        }
      }
    },
  );
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
    // SessionStore persists the authenticated session in platform secure
    // storage. Do not duplicate a bearer token into SharedPreferences.
    await prefs.remove(_backgroundSessionKey);
    await prefs.setBool(_trackingActiveKey, true);
    await _recordTrackingHealthEvent(
      'TRACKING_STARTED',
      attendanceLogId: attendanceLogId,
      details: 'On-duty location tracking started.',
      throttle: false,
    );
    await _recordBatteryOptimizationStatus(attendanceLogId: attendanceLogId);
    unawaited(_flushTrackingHealthEvents());

    try {
      final isRunning = await _service.isRunning().timeout(
            const Duration(seconds: 1),
            onTimeout: () => false,
          );
      if (!isRunning) {
        await _service.startService();
      }
    } catch (e) {
      await _recordTrackingHealthEvent(
        'LOCATION_STREAM_ERROR',
        attendanceLogId: attendanceLogId,
        details: 'Unable to start the background tracking service.',
      );
      if (kDebugMode) {
        debugPrint('[BackgroundService] startTracking error: $e');
      }
    }
  }

  static Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final attendanceLogId = prefs.getString(_attendanceLogIdKey);
    await _recordTrackingHealthEvent(
      'TRACKING_STOPPED',
      attendanceLogId: attendanceLogId,
      details: 'On-duty location tracking stopped.',
      throttle: false,
    );
    await _flushTrackingHealthEvents();
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
