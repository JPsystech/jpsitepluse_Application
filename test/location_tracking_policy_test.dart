import 'package:flutter_test/flutter_test.dart';
import 'package:sitepulse_engineer/core/services/location_tracking_policy.dart';

void main() {
  group('LocationTrackingPolicy.shouldAccept', () {
    test('accepts a realistic movement point', () {
      expect(
        LocationTrackingPolicy.shouldAccept(
          isDutyActive: true,
          isMocked: false,
          accuracyMeters: 35,
          elapsedSeconds: 60,
          distanceMeters: 80,
        ),
        isTrue,
      );
    });

    test('accepts a simulated four kilometre route', () {
      var acceptedPoints = 1; // Initial stream fix.
      for (var travelledMeters = 100;
          travelledMeters <= 4000;
          travelledMeters += 100) {
        if (LocationTrackingPolicy.shouldAccept(
          isDutyActive: true,
          isMocked: false,
          accuracyMeters: 25,
          elapsedSeconds: 60,
          distanceMeters: 100,
        )) {
          acceptedPoints++;
        }
      }

      expect(acceptedPoints, 41);
    });

    test('rejects inactive, mocked, inaccurate, stationary and impossible points', () {
      bool accepts({
        bool active = true,
        bool mocked = false,
        double accuracy = 35,
        int elapsed = 60,
        double distance = 80,
      }) => LocationTrackingPolicy.shouldAccept(
        isDutyActive: active,
        isMocked: mocked,
        accuracyMeters: accuracy,
        elapsedSeconds: elapsed,
        distanceMeters: distance,
      );

      expect(accepts(active: false), isFalse);
      expect(accepts(mocked: true), isFalse);
      expect(accepts(accuracy: 201), isFalse);
      expect(accepts(distance: 10), isFalse);
      expect(accepts(elapsed: 1, distance: 100), isFalse);
    });
  });

  group('LocationTrackingPolicy.isDuplicate', () {
    test('rejects simultaneous copies of the same GPS fix', () {
      expect(
        LocationTrackingPolicy.isDuplicate(
          elapsedSeconds: 1,
          distanceMeters: 0.5,
        ),
        isTrue,
      );
    });

    test('keeps a later or meaningfully different fix', () {
      expect(
        LocationTrackingPolicy.isDuplicate(
          elapsedSeconds: 60,
          distanceMeters: 0.5,
        ),
        isFalse,
      );
      expect(
        LocationTrackingPolicy.isDuplicate(
          elapsedSeconds: 1,
          distanceMeters: 20,
        ),
        isFalse,
      );
    });
  });
}
