class LocationTrackingPolicy {
  const LocationTrackingPolicy._();

  static bool shouldAccept({
    required bool isDutyActive,
    required bool isMocked,
    required double accuracyMeters,
    required int elapsedSeconds,
    required double distanceMeters,
  }) {
    if (!isDutyActive || isMocked || accuracyMeters > 200) return false;
    if (elapsedSeconds < 10 || distanceMeters < 15) return false;
    if (distanceMeters / elapsedSeconds > 70) return false;
    return true;
  }

  static bool isDuplicate({
    required int elapsedSeconds,
    required double distanceMeters,
  }) => elapsedSeconds <= 5 && distanceMeters < 5;
}
