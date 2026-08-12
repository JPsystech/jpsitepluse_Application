import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter/services.dart';
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

  runApp(const SitePulseAppFoundation());
}
