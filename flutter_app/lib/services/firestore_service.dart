import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> createUser(String uid, String? email) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'createdAt': Timestamp.now(),
      });
    } catch (error) {
      throw ("Error in adding user: $uid, to db. Error: $error");
    }
  }

  static Future<void> saveStudySession(Map<String, dynamic> sessionData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    final sessionsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions');

    final docRef = sessionsRef.doc();
    sessionData['sessionId'] = docRef.id;
    await docRef.set(sessionData);
  }

  static Future<void> updateStudySession(String sessionId, Map<String, dynamic> sessionData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(sessionId)
        .update(sessionData);
  }

  static Future<List<Map<String, dynamic>>> getStudySessions({String? sortBy, bool? ascending}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user logged in");

      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions');

      // Apply sorting based on parameters
      if (sortBy == 'deadline') {
        query = query.orderBy('examDeadline', descending: ascending == false);
      } else if (sortBy == 'name') {
        query = query.orderBy('sessionName', descending: ascending == false);
      } else {
        // Default sorting by creation date
        query = query.orderBy('createdAt', descending: false);
      }

      final sessionsSnapshot = await query.get();

      return sessionsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;  // Include document ID
        return data;
      }).toList();
    } catch (e) {
      print('Error getting study sessions: $e');
      rethrow;
    }
  }

  static Future<void> deleteStudySession(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(sessionId)
        .delete();
  }
}