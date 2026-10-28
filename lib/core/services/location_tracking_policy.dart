import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sitepulse_engineer/core/services/mobile_policy_service.dart';

class LocationTrackingPolicy {
  const LocationTrackingPolicy._();

  static bool get _isTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static bool shouldAccept({
    required bool isDutyActive,
    required bool isMocked,
    required double accuracyMeters,
    required int elapsedSeconds,
    required double distanceMeters,
  }) {
    // Allow mock locations in debug mode for Android Emulator GPX/KML route testing
    final effectiveMocked = (kDebugMode && !_isTest) ? false : isMocked;
    final policy = MobilePolicyService.current;
    if (!isDutyActive || effectiveMocked || accuracyMeters > policy.trackingMaxAccuracyM) return false;
    
    // In debug mode, accept all valid positions to test emulator route simulation smoothly
    if (kDebugMode && !_isTest) return true;

    if (elapsedSeconds < policy.trackingUpdateIntervalSeconds || distanceMeters < policy.trackingMinMovementM) return false;
    if (distanceMeters / elapsedSeconds > policy.trackingMaxSpeedMps) return false;
    return true;
  }

  static bool isDuplicate({
    required int elapsedSeconds,
    required double distanceMeters,
  }) {
    if (kDebugMode && !_isTest) return false;
    return elapsedSeconds <= 5 && distanceMeters < 5;
  }
}
