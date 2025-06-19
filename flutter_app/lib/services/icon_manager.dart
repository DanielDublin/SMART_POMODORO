import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'app_icon_service.dart';

class IconManager {
  static Future<void> checkAndUpdateIcon(String uid, [String? planId]) async {
    if (!Platform.isIOS) return; // Only proceed on iOS
    
    final now = DateTime.now();
    
    // Only check after 22:00
    if (now.hour < 22) {
      await AppIconService.setNormalIcon();
      return;
    }

    try {
      // Get all active study plans
      final plansQuery = planId != null 
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('sessions')
              .where(FieldPath.documentId, isEqualTo: planId)
          : FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('sessions')
              .where('isActive', isEqualTo: true);

      final planDocs = await plansQuery.get();
      
      if (planDocs.docs.isEmpty) return;

      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      bool shouldStudyToday = false;
      bool hasCompletedAnySession = false;

      // Check each plan
      for (final planDoc in planDocs.docs) {
        // Check if today is a study day for this plan
        final selectedDays = (planDoc.data()['selectedDays'] as List?)
            ?.map((ts) => (ts as Timestamp).toDate())
            .toList() ?? [];

        final isStudyDay = selectedDays.any((date) =>
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day);

        if (isStudyDay) {
          shouldStudyToday = true;
          // Check if any sessions were completed today
          final todayLogs = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('session_logs')
              .where('sessionPlanId', isEqualTo: planDoc.id)
              .where('sessionType', isEqualTo: 'study')
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
              .where('startTime', isLessThan: Timestamp.fromDate(todayEnd))
              .get();

          if (todayLogs.docs.isNotEmpty) {
            hasCompletedAnySession = true;
            break;
          }
        }
      }

      // Update icon based on study status
      if (shouldStudyToday && !hasCompletedAnySession) {
        debugPrint('Setting gloomy icon - study needed today but no sessions completed');
        await AppIconService.setGloomyIcon();
      } else {
        debugPrint('Setting normal icon - no study needed or sessions completed');
        await AppIconService.setNormalIcon();
      }
    } catch (e) {
      debugPrint('Error in checkAndUpdateIcon: $e');
      // Silently fail on errors
    }
  }
} 