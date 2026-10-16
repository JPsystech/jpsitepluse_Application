import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/services/location_tracking_policy.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class LiveLocationTrackingService {
  LiveLocationTrackingService._();
  static final LiveLocationTrackingService instance = LiveLocationTrackingService._();

  static const String _offlineQueueKey = 'sitepulse_offline_location_queue_v1';
  static const String _dutyActiveKey = 'sitepulse_duty_tracking_active';
  static const String _dutyStartedAtKey = 'sitepulse_duty_tracking_started_at';
  static const String _attendanceLogIdKey = 'sitepulse_duty_attendance_log_id';
  static const int _dutyIntervalSeconds = 60;
  static const int _dutyDistanceFilterMeters = 30;
  static const int _heartbeatSeconds = 300;
  static const int _lastKnownMaxAgeSeconds = 30;
  static const int _maxDutySessionHours = 18;
  static const int _batteryRefreshMinutes = 5;

  StreamSubscription<Position>? _positionStreamSub;
  Timer? _heartbeatTimer;
  bool _isDutyActive = false;
  bool _isSyncingOffline = false;
  bool _isSendingPosition = false;
  Position? _lastAcceptedPosition;
  DateTime? _lastSubmittedAt;
  double? _lastSubmittedLatitude;
  double? _lastSubmittedLongitude;
  DateTime? _lastBatteryReadAt;
  int? _cachedBatteryLevel;
  bool _cachedIsCharging = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get isTracking => _isDutyActive;

  Future<void> initialize() async {
    await SessionStore.load();
    final prefs = await SharedPreferences.getInstance();
    final wasActive = prefs.getBool(_dutyActiveKey) ?? false;
    final startedAt = DateTime.tryParse(prefs.getString(_dutyStartedAtKey) ?? '');
    final isExpired = startedAt == null ||
        DateTime.now().toUtc().difference(startedAt.toUtc()).inHours >= _maxDutySessionHours;

    if (wasActive && SessionStore.current != null && !isExpired) {
      _isDutyActive = true;
      await _startSession();
    } else if (wasActive) {
      await _clearPersistedDutyState(prefs);
    }

    // Listen to network changes to flush offline queue
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        syncOfflineQueue();
      }
    });
  }

  void dispose() {
    unawaited(_stopSession());
    _connectivitySub?.cancel();
  }

  /// Starts tracking when engineer punches in.
  Future<void> startDutyTracking({String? attendanceLogId}) async {
    _isDutyActive = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dutyActiveKey, true);
    await prefs.setString(_dutyStartedAtKey, DateTime.now().toUtc().toIso8601String());
    final cleanAttendanceLogId = (attendanceLogId ?? '').trim();
    if (cleanAttendanceLogId.isNotEmpty) {
      await prefs.setString(_attendanceLogIdKey, cleanAttendanceLogId);
    }
    await _startSession();
  }

  /// Stops tracking when engineer punches out or logs out.
  Future<void> stopDutyTracking() async {
    _isDutyActive = false;
    await _stopSession();
    final prefs = await SharedPreferences.getInstance();
    await _clearPersistedDutyState(prefs);
  }

  Future<void> _clearPersistedDutyState(SharedPreferences prefs) async {
    await prefs.remove(_dutyActiveKey);
    await prefs.remove(_dutyStartedAtKey);
    await prefs.remove(_attendanceLogIdKey);
  }

  Future<void> _stopSession() async {
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastAcceptedPosition = null;
    _lastSubmittedAt = null;
    _lastSubmittedLatitude = null;
    _lastSubmittedLongitude = null;
  }

  Future<void> _startSession() async {
    await _positionStreamSub?.cancel();
    _heartbeatTimer?.cancel();

    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _dutyDistanceFilterMeters,
        intervalDuration: const Duration(seconds: _dutyIntervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'JP SitePulse',
          notificationText: 'On-duty location tracking active',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: _dutyDistanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _dutyDistanceFilterMeters,
      );
    }

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _handlePosition,
      onError: (err) {
        if (kDebugMode) {
          debugPrint('Live location stream error: $err');
        }
      },
    );

    // A distance-filtered stream can remain silent or be suspended. A balanced
    // accuracy fallback fix provides a route point without continuously running
    // high-accuracy GPS.
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatSeconds),
      (_) => unawaited(captureAndSendLocation(source: 'LIVE', preferFresh: true)),
    );
  }

  Future<void> _handlePosition(Position position) async {
    if (!_isDutyActive || position.isMocked || position.accuracy > 200) return;

    final previous = _lastAcceptedPosition;
    if (previous != null) {
      final elapsedSeconds = position.timestamp.difference(previous.timestamp).inSeconds.abs();
      final distanceMeters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      if (!LocationTrackingPolicy.shouldAccept(
        isDutyActive: _isDutyActive,
        isMocked: position.isMocked,
        accuracyMeters: position.accuracy,
        elapsedSeconds: elapsedSeconds,
        distanceMeters: distanceMeters,
      )) {
        return;
      }
    }

    _lastAcceptedPosition = position;
    if (_isSendingPosition) {
      await _enqueuePosition(position, source: 'LIVE');
      return;
    }

    _isSendingPosition = true;
    try {
      await _sendPosition(position, source: 'LIVE');
    } finally {
      _isSendingPosition = false;
      unawaited(syncOfflineQueue());
    }
  }

  Future<Position?> _getRecentLastKnownPosition() async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown == null) return null;

    final ageSeconds = DateTime.now().toUtc().difference(lastKnown.timestamp.toUtc()).inSeconds.abs();
    if (ageSeconds > _lastKnownMaxAgeSeconds) return null;
    return lastKnown;
  }

  /// Captures GPS and sends to backend; queues locally if offline.
  Future<void> captureAndSendLocation({String source = 'LIVE', bool preferFresh = false}) async {
    await SessionStore.load();
    if (SessionStore.current == null) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      Position? position;
      if (!preferFresh) {
        try {
          position = await _getRecentLastKnownPosition();
        } catch (_) {}
      }

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            ),
          );
        } catch (_) {}
      }

      if (position == null) {
        try {
          position = await _getRecentLastKnownPosition();
        } catch (_) {}
      }

      if (position != null && !position.isMocked && position.accuracy <= 200) {
        await _sendPosition(position, source: source);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Location tracking capture error: $e');
      }
    }
  }

  Future<void> _sendPosition(Position position, {required String source}) async {
    await SessionStore.load();
    if (SessionStore.current == null) return;

    // getCurrentPosition (heartbeat) and getPositionStream can deliver the same
    // GPS fix concurrently. Reserve it before the network await to avoid two DB
    // breadcrumbs for one fix.
    final submittedAt = _lastSubmittedAt;
    if (submittedAt != null &&
        _lastSubmittedLatitude != null &&
        _lastSubmittedLongitude != null) {
      final elapsedSeconds =
          position.timestamp.toUtc().difference(submittedAt).inSeconds.abs();
      final distanceMeters = Geolocator.distanceBetween(
        _lastSubmittedLatitude!,
        _lastSubmittedLongitude!,
        position.latitude,
        position.longitude,
      );
      if (LocationTrackingPolicy.isDuplicate(
        elapsedSeconds: elapsedSeconds,
        distanceMeters: distanceMeters,
      )) {
        return;
      }
    }
    _lastSubmittedAt = position.timestamp.toUtc();
    _lastSubmittedLatitude = position.latitude;
    _lastSubmittedLongitude = position.longitude;

    await _refreshBatteryIfNeeded();
    final attendanceLogId = await _getAttendanceLogId();

    final payload = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_m': position.accuracy,
      'speed_mps': position.speed,
      'heading': position.heading,
      'battery_percent': _cachedBatteryLevel,
      'is_charging': _cachedIsCharging,
      'is_mocked': position.isMocked,
      'attendance_log_id': attendanceLogId,
      'source': source,
      'captured_at': position.timestamp.toUtc().toIso8601String(),
    };

    await _sendPayload(payload);
  }

  Future<void> sendKnownLocation({
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) async {
    if (!_isDutyActive) return;
    await _refreshBatteryIfNeeded();
    final attendanceLogId = await _getAttendanceLogId();
    await _sendPayload({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'speed_mps': null,
      'heading': null,
      'battery_percent': _cachedBatteryLevel,
      'is_charging': _cachedIsCharging,
      'is_mocked': false,
      'attendance_log_id': attendanceLogId,
      'source': 'LIVE',
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _refreshBatteryIfNeeded() async {
    final now = DateTime.now();
    if (_lastBatteryReadAt != null &&
        now.difference(_lastBatteryReadAt!).inMinutes < _batteryRefreshMinutes) {
      return;
    }

    try {
      final battery = Battery();
      _cachedBatteryLevel = await battery.batteryLevel;
      final state = await battery.batteryState;
      _cachedIsCharging = state == BatteryState.charging || state == BatteryState.full;
      _lastBatteryReadAt = now;
    } catch (_) {}
  }

  Future<String?> _getAttendanceLogId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = (prefs.getString(_attendanceLogIdKey) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _enqueuePosition(Position position, {required String source}) async {
    await _refreshBatteryIfNeeded();
    final attendanceLogId = await _getAttendanceLogId();
    await _enqueueOffline({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_m': position.accuracy,
      'speed_mps': position.speed,
      'heading': position.heading,
      'battery_percent': _cachedBatteryLevel,
      'is_charging': _cachedIsCharging,
      'is_mocked': position.isMocked,
      'attendance_log_id': attendanceLogId,
      'source': source,
      'captured_at': position.timestamp.toUtc().toIso8601String(),
    });
  }

  Future<void> _sendPayload(Map<String, dynamic> payload) async {
    try {
      final dio = await ApiClient.instance.dio;
      await dio.post(
        '/api/v1/engineer/live-location',
        data: payload,
      );

    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == null || statusCode >= 500) {
        await _enqueueOffline(payload);
      } else if (kDebugMode) {
        debugPrint('Live location rejected by server: ${e.response?.data ?? e.message}');
      }
    } catch (e) {
      // Offline fallback: save to local queue
      await _enqueueOffline(payload);
    }
  }

  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_offlineQueueKey) ?? '[]';
      final List<dynamic> queue = jsonDecode(queueStr);

      payload['source'] = 'OFFLINE_SYNC';
      queue.add(payload);

      // Keep maximum 200 offline points to avoid bloat
      if (queue.length > 200) {
        queue.removeRange(0, queue.length - 200);
      }

      await prefs.setString(_offlineQueueKey, jsonEncode(queue));
    } catch (_) {}
  }

  /// Flushes queued offline location points to the batch ingest API.
  Future<void> syncOfflineQueue() async {
    if (_isSyncingOffline) return;
    _isSyncingOffline = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_offlineQueueKey) ?? '[]';
      final List<dynamic> queue = jsonDecode(queueStr);

      if (queue.isEmpty) {
        _isSyncingOffline = false;
        return;
      }

      final dio = await ApiClient.instance.dio;
      final payload = {
        'locations': queue,
      };

      final resp = await dio.post(
        '/api/v1/engineer/live-locations/batch',
        data: payload,
      );

      if (resp.statusCode == 200) {
        await prefs.remove(_offlineQueueKey);
        if (kDebugMode) {
          debugPrint('Synced ${queue.length} offline location pings to server.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Offline location sync retry failed: $e');
      }
    } finally {
      _isSyncingOffline = false;
    }
  }
}
