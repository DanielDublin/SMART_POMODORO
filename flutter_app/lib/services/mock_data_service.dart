import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();

  /// Generates and uploads mock session logs for the current user's study sessions.
  Future<void> generateMockLogsForCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint("No user is currently logged in.");
        return;
      }

      final userId = currentUser.uid;
      debugPrint("Generating mock data for current user: ${currentUser.email} (ID: $userId)");

      // Get all study sessions for the current user
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('study_sessions')
          .get();

      if (sessionsSnapshot.docs.isEmpty) {
        debugPrint("No study sessions found for the current user.");
        return;
      }

      debugPrint("Found ${sessionsSnapshot.docs.length} study sessions for the current user.");

      // Create a batch write to upload all logs efficiently
      final batch = _firestore.batch();
      final logsCollectionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('session_logs');

      // Generate logs for each study session
      for (final sessionDoc in sessionsSnapshot.docs) {
        final sessionId = sessionDoc.id;
        debugPrint("Generating logs for session: $sessionId");

        // Generate 2-5 logs for each session
        final numberOfLogs = 2 + _random.nextInt(4);
        debugPrint("Generating $numberOfLogs logs for session $sessionId");

        DateTime cursorTime = DateTime.now();

        for (int i = 0; i < numberOfLogs; i++) {
          // Generate data for one mock log
          final sessionType = _getRandomSessionType();
          final duration = _getRandomDuration(sessionType);
          final status = _random.nextDouble() > 0.1 ? 'completed' : 'incomplete';

          // Make the timestamps sequential and in the past
          final endTime = cursorTime.subtract(Duration(days: _random.nextInt(2), hours: _random.nextInt(12)));
          final startTime = endTime.subtract(Duration(minutes: duration));
          cursorTime = startTime; // Move the cursor back for the next log

          // Create the document data map
          final logData = {
            'uid': userId,
            'sessionPlanId': sessionId,
            'startTime': Timestamp.fromDate(startTime),
            'endTime': Timestamp.fromDate(endTime),
            'duration': duration,
            'sessionType': sessionType,
            'status': status,
            'createdAt': FieldValue.serverTimestamp(),
          };
          
          // Add the new log document to the batch
          final newLogDocRef = logsCollectionRef.doc();
          batch.set(newLogDocRef, logData);
          debugPrint("Added log ${i + 1}/$numberOfLogs to batch for session $sessionId");
        }
      }

      // Commit the batch write to Firestore
      await batch.commit();
      debugPrint("Successfully uploaded mock data for current user.");
    } catch (e, stackTrace) {
      debugPrint("An error occurred during mock data generation: $e");
      debugPrint("Stack trace: $stackTrace");
      rethrow;
    }
  }

  String _getRandomSessionType() {
    // Make 'study' sessions more likely
    final roll = _random.nextInt(10); // 0-9
    if (roll < 6) return 'study'; // 60% chance
    if (roll < 9) return 'short_break'; // 30% chance
    return 'long_break'; // 10% chance
  }

  int _getRandomDuration(String sessionType) {
    switch (sessionType) {
      case 'study':
        return 20 + _random.nextInt(11); // 20-30 minutes
      case 'short_break':
        return 5 + _random.nextInt(6); // 5-10 minutes
      case 'long_break':
        return 15 + _random.nextInt(16); // 15-30 minutes
      default:
        return 25;
    }
  }
} 