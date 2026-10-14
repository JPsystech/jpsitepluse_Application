import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class LiveLocationTrackingService {
  LiveLocationTrackingService._();
  static final LiveLocationTrackingService instance = LiveLocationTrackingService._();

  static const String _offlineQueueKey = 'sitepulse_offline_location_queue_v1';
  static const String _transitActiveKey = 'sitepulse_transit_mode_active';

  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isDutyActive = false;
  bool _isTransitActive = false;
  bool _isSyncingOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get isTracking => _isDutyActive || _isTransitActive;
  bool get isTransitActive => _isTransitActive;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isTransitActive = prefs.getBool(_transitActiveKey) ?? false;

    // Listen to network changes to flush offline queue
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        syncOfflineQueue();
      }
    });

    if (_isTransitActive) {
      _startSession();
    }
  }

  void dispose() {
    _stopSession();
    _connectivitySub?.cancel();
  }

  /// Starts tracking when engineer punches in.
  void startDutyTracking() {
    _isDutyActive = true;
    _startSession();
    captureAndSendLocation(source: 'LIVE');
  }

  /// Stops tracking when engineer punches out or logs out.
  void stopDutyTracking() {
    _isDutyActive = false;
    if (!_isTransitActive) {
      _stopSession();
    } else {
      _startSession();
    }
  }

  /// Toggles transit mode for outstation travel (e.g. traveling to site from UP).
  Future<void> setTransitMode(bool enabled) async {
    _isTransitActive = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_transitActiveKey, enabled);

    if (enabled) {
      _startSession();
      captureAndSendLocation(source: 'TRANSIT');
    } else {
      if (!_isDutyActive) {
        _stopSession();
      } else {
        _startSession();
      }
    }
  }

  void _stopSession() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  void _startSession() {
    _positionStreamSub?.cancel();
    _trackingTimer?.cancel();

    final intervalMinutes = _isTransitActive && !_isDutyActive ? 7 : 1;
    final distanceFilter = _isTransitActive && !_isDutyActive ? 100 : 25;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: distanceFilter,
        intervalDuration: Duration(minutes: intervalMinutes),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'JP SitePulse',
          notificationText: _isTransitActive && !_isDutyActive
              ? 'Transit / travel tracking active'
              : 'On-duty location tracking active',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: androidSettings,
      ).listen(
        (Position pos) {
          final source = _isTransitActive && !_isDutyActive ? 'TRANSIT' : 'LIVE';
          _sendPosition(pos, source: source);
        },
        onError: (err) {
          if (kDebugMode) {
            debugPrint('Live location stream error: $err');
          }
        },
      );
    }

    // Keep periodic timer as fallback heartbeat
    final duration = Duration(minutes: intervalMinutes);
    _trackingTimer = Timer.periodic(duration, (_) {
      final source = _isTransitActive && !_isDutyActive ? 'TRANSIT' : 'LIVE';
      captureAndSendLocation(source: source);
    });
  }

  /// Captures GPS and sends to backend; queues locally if offline.
  Future<void> captureAndSendLocation({String source = 'LIVE'}) async {
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
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && DateTime.now().toUtc().difference(lastKnown.timestamp.toUtc()).inSeconds.abs() <= 120) {
          position = lastKnown;
        }
      } catch (_) {}

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (_) {}
      }

      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (position != null) {
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

    int? batteryLevel;
    bool isCharging = false;
    try {
      final battery = Battery();
      batteryLevel = await battery.batteryLevel;
      final state = await battery.batteryState;
      isCharging = state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {}

    final payload = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_m': position.accuracy,
      'speed_mps': position.speed,
      'heading': position.heading,
      'battery_percent': batteryLevel,
      'is_charging': isCharging,
      'is_mocked': position.isMocked,
      'source': source,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _sendPayload(payload);
  }

  Future<void> _sendPayload(Map<String, dynamic> payload) async {
    try {
      final dio = await ApiClient.instance.dio;
      final resp = await dio.post(
        '/api/v1/engineer/live-location',
        data: payload,
      );

      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final status = data['status']?.toString();
        // If site arrival detected, automatically shut off transit mode
        if (status == 'ARRIVED' && _isTransitActive) {
          await setTransitMode(false);
        }
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
