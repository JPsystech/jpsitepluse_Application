import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:sitepulse_engineer/core/services/push_notification_registration_service.dart';
import 'core/services/notification_service.dart';
import "app.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final ImagePickerPlatform implementation =
      ImagePickerPlatform.instance;

  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }

  try {
    await PushNotificationRegistrationService.initializeFirebase();
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint("Firebase / Notification init failed: $e");
  }

  runApp(const SitePulseAppFoundation());
}
