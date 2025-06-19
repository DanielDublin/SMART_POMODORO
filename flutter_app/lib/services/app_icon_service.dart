import 'package:flutter/services.dart';

class AppIconService {
  static const platform = MethodChannel('com.iot.technion.smart_pomodoro/app_icon');

  static Future<void> setGloomyIcon() async {
    try {
      await platform.invokeMethod('setAlternateIcon', {'iconName': 'gloomy'});
    } on PlatformException catch (e) {
      print('Error changing app icon: ${e.message}');
    }
  }

  static Future<void> setNormalIcon() async {
    try {
      await platform.invokeMethod('setAlternateIcon', {'iconName': null});
    } on PlatformException catch (e) {
      print('Error resetting app icon: ${e.message}');
    }
  }
} 