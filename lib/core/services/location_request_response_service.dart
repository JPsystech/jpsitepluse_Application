import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class LocationRequestResponseService {
  LocationRequestResponseService._();

  static Future<void> handleLocationRequest(String requestId) async {
    final cleanRequestId = requestId.trim();
    if (cleanRequestId.isEmpty) return;

    await SessionStore.load();
    if (SessionStore.current == null) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _postFailure(cleanRequestId, 'Location service (GPS) is disabled on the engineer device.');
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await _postFailure(
          cleanRequestId,
          'Location permission is not granted. Please open the app and allow location access.',
        );
        return;
      }

      Position? position;

      // 1. Fast path: check if the device already has a fresh cached position (< 2 minutes old)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          final ageSec = DateTime.now().toUtc().difference(lastKnown.timestamp.toUtc()).inSeconds.abs();
          if (ageSec <= 120) {
            position = lastKnown;
            if (kDebugMode) {
              debugPrint('Used fresh lastKnownPosition (${ageSec}s old)');
            }
          }
        }
      } catch (_) {}

      // 2. Android: Use foreground service stream so Android does not throttle GPS when app is closed/in background
      if (position == null && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final androidSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            timeLimit: const Duration(seconds: 12),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'JP SitePulse',
              notificationText: 'Verifying engineer location for admin request...',
              enableWakeLock: true,
            ),
          );

          position = await Geolocator.getPositionStream(
            locationSettings: androidSettings,
          ).first.timeout(const Duration(seconds: 12));
        } catch (err) {
          if (kDebugMode) {
            debugPrint('Foreground stream position failed ($err), trying fallback...');
          }
        }
      }

      // 3. Fallback or iOS: standard getCurrentPosition
      if (position == null) {
        try {
          final fallbackSettings = defaultTargetPlatform == TargetPlatform.android
              ? AndroidSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: const Duration(seconds: 8),
                  forceLocationManager: true,
                )
              : const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 8),
                );
          position = await Geolocator.getCurrentPosition(locationSettings: fallbackSettings);
        } catch (err2) {
          if (kDebugMode) {
            debugPrint('Fallback getCurrentPosition failed ($err2)');
          }
        }
      }

      // 4. Fallback to cached last known position from the OS
      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (position == null) {
        await _postFailure(cleanRequestId, 'Unable to acquire GPS coordinates (no signal or timeout).');
        return;
      }

      int? batteryLevel;
      bool isCharging = false;
      try {
        final battery = Battery();
        batteryLevel = await battery.batteryLevel;
        final state = await battery.batteryState;
        isCharging = state == BatteryState.charging || state == BatteryState.full;
      } catch (_) {}

      await _postResult(
        cleanRequestId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        batteryPercent: batteryLevel,
        isCharging: isCharging,
        capturedAt: position.timestamp.toUtc().toIso8601String(),
      );
    } catch (e) {
      await _postFailure(cleanRequestId, 'Unable to capture location: $e');
    }
  }

  static Future<void> _postResult(
    String requestId, {
    required double latitude,
    required double longitude,
    required double accuracyM,
    required String capturedAt,
    int? batteryPercent,
    bool isCharging = false,
  }) async {
    try {
      final dio = await ApiClient.instance.dio;
      await dio.post(
        '/api/v1/engineer/location-requests/$requestId/response',
        data: {
          'status': 'COMPLETED',
          'latitude': latitude,
          'longitude': longitude,
          'accuracy_m': accuracyM,
          'battery_percent': batteryPercent,
          'is_charging': isCharging,
          'captured_at': capturedAt,
        },
      );
      if (kDebugMode) {
        debugPrint('Location request response posted successfully: $requestId');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to post requested location: ${e.response?.data ?? e.message}');
      }
    }
  }

  static Future<void> _postFailure(String requestId, String reason) async {
    try {
      final dio = await ApiClient.instance.dio;
      await dio.post(
        '/api/v1/engineer/location-requests/$requestId/response',
        data: {
          'status': 'FAILED',
          'failure_reason': reason,
        },
      );
      if (kDebugMode) {
        debugPrint('Posted location failure: $requestId, reason: $reason');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to post location failure: ${e.response?.data ?? e.message}');
      }
    }
  }
}
