import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class AppIconService {
  static const platform = MethodChannel('com.iot.technion.smart_pomodoro/app_icon');

  static Future<void> setNormalIcon() async {
    if (!Platform.isIOS) return; // Only proceed on iOS
    try {
      await platform.invokeMethod('setAlternateIcon', null);
    } catch (e) {
      debugPrint('Failed to set normal icon: $e');
      // Silently fail on unsupported platforms
    }
  }
} 