import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_icon_service.dart';

class IconManager {
  static Future<void> checkAndUpdateIcon(String uid, [String? planId]) async {
    final now = DateTime.now();
    
    // Only check after 22:00
    if (now.hour < 22) {
      await AppIconService.setNormalIcon();
      return;
    }

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

        // Check if any sessions completed today for this plan
        final sessions = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('session_logs')
            .where('sessionPlanId', isEqualTo: planDoc.id)
            .where('sessionType', isEqualTo: 'study')
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('startTime', isLessThan: Timestamp.fromDate(todayEnd))
            .get();

        if (sessions.docs.isNotEmpty) {
          hasCompletedAnySession = true;
          break; // If we found any completed session, we can stop checking
        }
      }
    }

    // Set gloomy icon if it's after 22:00, it's a study day for any plan, and no sessions completed
    if (shouldStudyToday && !hasCompletedAnySession) {
      await AppIconService.setGloomyIcon();
    } else {
      await AppIconService.setNormalIcon();
    }
  }
} 