import 'package:flutter/foundation.dart';

class LocationTrackingPolicy {
  const LocationTrackingPolicy._();

  static bool shouldAccept({
    required bool isDutyActive,
    required bool isMocked,
    required double accuracyMeters,
    required int elapsedSeconds,
    required double distanceMeters,
  }) {
    // Allow mock locations in debug mode for Android Emulator GPX/KML route testing
    final effectiveMocked = kDebugMode ? false : isMocked;
    if (!isDutyActive || effectiveMocked || accuracyMeters > 200) return false;
    
    // In debug mode, accept all valid positions to test emulator route simulation smoothly
    if (kDebugMode) return true;

    if (elapsedSeconds < 10 || distanceMeters < 15) return false;
    if (distanceMeters / elapsedSeconds > 70) return false;
    return true;
  }

  static bool isDuplicate({
    required int elapsedSeconds,
    required double distanceMeters,
  }) {
    if (kDebugMode) return false;
    return elapsedSeconds <= 5 && distanceMeters < 5;
  }
}
