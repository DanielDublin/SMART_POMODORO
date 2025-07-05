import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'app_icon_service.dart';

class IconManager {
  static Future<void> checkAndUpdateIcon(String uid, [String? planId]) async {
    if (!Platform.isIOS) return; // Only proceed on iOS
    
    // Always set normal icon 
    await AppIconService.setNormalIcon();
  }
} 