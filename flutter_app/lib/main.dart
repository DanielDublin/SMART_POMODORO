import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/study_plans_list_screen.dart';
import 'services/icon_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  }
  catch(error) {
    print("error getting .env");
    return;
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check icon state on app start
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await IconManager.checkAndUpdateIcon(user.uid);
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Pomodoro',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            // Check icon state when user logs in
            _checkIconForUser(snapshot.data!);
            return StudyPlansListScreen();
          }
          
          return LoginScreen();
        },
      ),
    );
  }

  Future<void> _checkIconForUser(User user) async {
    try {
      await IconManager.checkAndUpdateIcon(user.uid);
    } catch (e) {
      print('Error checking icon for user: $e');
    }
  }
}