import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _notificationShownThisSession = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    
    // Request permissions after initialization
    await _requestPermissions();
    
    _initialized = true;
    _notificationShownThisSession = false; // Reset flag on app start
    debugPrint('Notification service initialized');
  }

  static Future<void> _requestPermissions() async {
    try {
      final androidGranted = await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestPermission();
      
      final iosGranted = await _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Android notification permission: $androidGranted');
      debugPrint('iOS notification permission: $iosGranted');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  static Future<void> checkAndShowDailyReminder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in, skipping notification check');
        return;
      }

      final now = DateTime.now();
      debugPrint('=== DAILY REMINDER CHECK START ===');
      debugPrint('Current time: ${now.toString()}');
      debugPrint('Notification already shown this session: $_notificationShownThisSession');

      // Only show notification if it hasn't been shown this session
      if (_notificationShownThisSession) {
        debugPrint('Notification already shown this session. Skipping.');
        return;
      }

      // Get all active study plans
      final activePlans = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .where('isActive', isEqualTo: true)
          .get();

      debugPrint('Found ${activePlans.docs.length} active study plans');

      if (activePlans.docs.isEmpty) {
        debugPrint('No active study plans found');
        return;
      }

      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      debugPrint('Today start: ${todayStart.toString()}');
      debugPrint('Today end: ${todayEnd.toString()}');
      
      List<String> plansNeedingReminders = [];

      // Check each plan
      for (final planDoc in activePlans.docs) {
        final data = planDoc.data();
        final planName = data['sessionName']?.toString() ?? 'Unnamed Plan';
        final selectedDays = (data['selectedDays'] as List?)
            ?.map((ts) => (ts as Timestamp).toDate())
            .toList() ?? [];

        debugPrint('--- Checking plan: $planName (ID: ${planDoc.id}) ---');
        debugPrint('Selected days count: ${selectedDays.length}');
        
        // Print all selected days for debugging
        for (int i = 0; i < selectedDays.length; i++) {
          debugPrint('Selected day $i: ${selectedDays[i].toString()}');
        }

        // Check if today is a study day for this plan
        final isStudyDay = selectedDays.any((date) {
          final isToday = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          debugPrint('Comparing ${date.toString()} with today: $isToday');
          return isToday;
        });

        debugPrint('Is today a study day for $planName: $isStudyDay');

        if (isStudyDay) {
          debugPrint('Today IS a study day for $planName, checking for completed sessions...');
          
          // Use a simpler query that doesn't require an index
          // Get all session logs for this plan and filter in memory
          final allLogs = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('session_logs')
              .where('sessionPlanId', isEqualTo: planDoc.id)
              .get();

          // Filter for study sessions that started today
          final todayLogs = allLogs.docs.where((doc) {
            final logData = doc.data();
            final sessionType = logData['sessionType'] as String?;
            final startTime = logData['startTime'] as Timestamp?;
            
            if (sessionType != 'study' || startTime == null) return false;
            
            final logDate = startTime.toDate();
            return logDate.year == now.year &&
                   logDate.month == now.month &&
                   logDate.day == now.day;
          }).toList();

          debugPrint('Found ${todayLogs.length} completed sessions today for plan: $planName');
          
          // Print details of any found sessions
          for (int i = 0; i < todayLogs.length; i++) {
            final logData = todayLogs[i].data();
            debugPrint('Session $i: ${logData.toString()}');
          }

          // If no sessions completed for this plan today, add to reminder list
          if (todayLogs.isEmpty) {
            plansNeedingReminders.add(planName);
            debugPrint('✓ Adding $planName to reminder list (no sessions today)');
          } else {
            debugPrint('✗ NOT adding $planName to reminder list (has sessions today)');
          }
        } else {
          debugPrint('Today is NOT a study day for $planName, skipping...');
        }
      }

      debugPrint('=== FINAL RESULT ===');
      debugPrint('Plans needing reminders: $plansNeedingReminders');

      // Show notification if there are plans that need reminders
      if (plansNeedingReminders.isNotEmpty) {
        debugPrint('🎯 Showing daily session reminder notification for plans: $plansNeedingReminders');
        await _showDailyReminderNotification(plansNeedingReminders);
        // Mark notification as shown for this session
        _notificationShownThisSession = true;
      } else {
        debugPrint('✅ No plans need reminders today');
      }
      
      debugPrint('=== DAILY REMINDER CHECK END ===');
    } catch (e) {
      debugPrint('❌ Error checking daily reminder: $e');
    }
  }

  static Future<void> _showDailyReminderNotification(List<String> planNames) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'daily_reminder_channel',
        'Daily Study Reminders',
        channelDescription: 'Reminders for daily study sessions',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      String notificationMessage;
      if (planNames.length == 1) {
        notificationMessage = 'Don\'t forget your daily session for "${planNames[0]}"!';
      } else {
        notificationMessage = 'Don\'t forget your daily sessions for: ${planNames.join(", ")}';
      }

      debugPrint('Showing notification: $notificationMessage');

      await _notifications.show(
        1, // Unique ID for daily reminder
        'Don\'t forget your Daily session!',
        notificationMessage,
        details,
      );
      
      debugPrint('Notification sent successfully');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  static Future<void> cancelDailyReminder() async {
    await _notifications.cancel(1);
  }
} 