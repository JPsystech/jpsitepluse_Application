import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter/services.dart';
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
    await Firebase.initializeApp();
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  runApp(const SitePulseAppFoundation());
}
