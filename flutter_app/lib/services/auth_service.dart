import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firestore_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    }
    catch (error) {
      throw("Error signing in with email and password: $error");
    }
  }

  static Future<void> register(String email, String password) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirestoreService.createUser(userCred.user!.uid, email);
    }
    catch (error) {
      throw("Error in registration with email and password: $error");
    }
  }

  static Future<UserCredential> signInWithGoogle() async {
    await _googleSignIn.signOut();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in aborted');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // Check if document exists
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        // Create user document if it doesn't exist
        await FirestoreService.createUser(user.uid, user.email);
        // await userDoc.set({
        //   'uid': user.uid,
        //   'email': user.email,
        //   // 'name': user.displayName,
        //   'createdAt': FieldValue.serverTimestamp(),
        // });
      }
    }
  return userCredential;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}