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

    await sessionsRef.add(sessionData);
  }
}