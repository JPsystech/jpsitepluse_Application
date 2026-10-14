import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/core/services/live_location_tracking_service.dart';

class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  static const String prefKey = 'has_seen_location_disclosure_v1';

  static Future<bool> shouldShow() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return false;
    }
    return true;
  }

  static Future<bool> showIfNeeded(BuildContext context) async {
    if (!context.mounted) return false;
    final needsPrompt = await shouldShow();
    if (!needsPrompt) return true;
    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const LocationDisclosureDialog(),
    );

    if (accepted == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Location Access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'JP SitePulse collects location data to enable the following features even when the app is closed or not in use during your work shift:',
              style: TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildFeatureBullet(
              icon: Icons.access_time_filled,
              title: 'Shift & Attendance Verification',
              desc: 'Confirms your arrival and presence within project geofenced boundaries for accurate punch records.',
            ),
            const SizedBox(height: 8),
            _buildFeatureBullet(
              icon: Icons.directions_transit_filled,
              title: 'Outstation Site Transit Tracking',
              desc: 'Allows site management to monitor transit progress when traveling to outstation project locations and detect site arrival.',
            ),
            const SizedBox(height: 8),
            _buildFeatureBullet(
              icon: Icons.shield,
              title: 'Field Safety & Coordination',
              desc: 'Ensures emergency response and team coordination while assigned on duty.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Note: Background tracking strictly turns off when you punch out or when transit is completed. Your personal off-duty time is never tracked.',
                style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            Navigator.of(context).pop(true);
            await _requestPermissions();
          },
          child: const Text('Agree & Continue'),
        ),
      ],
    );
  }

  Widget _buildFeatureBullet({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _requestPermissions() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // On Android, if foreground is granted, prompt for background location
      if (Platform.isAndroid && permission != LocationPermission.deniedForever) {
        if (permission == LocationPermission.whileInUse) {
          // Attempt requesting always
          final bgPerm = await Geolocator.requestPermission();
          if (bgPerm != LocationPermission.denied && bgPerm != LocationPermission.deniedForever) {
            permission = bgPerm;
          }
        }
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // Prime the device GPS/Network cache and report initial location to server
        LiveLocationTrackingService.instance.captureAndSendLocation(source: 'LOGIN');
      }
    } catch (_) {}
  }
}
