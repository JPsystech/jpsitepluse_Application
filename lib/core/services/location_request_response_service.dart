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
        await _postFailure(cleanRequestId, 'Location service is disabled on the engineer device');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await _postFailure(cleanRequestId, 'Location permission is not granted on the engineer device');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _postResult(
        cleanRequestId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        capturedAt: DateTime.now().toUtc().toIso8601String(),
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
