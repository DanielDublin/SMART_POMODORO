import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/study_plans_list_screen.dart';
import 'services/icon_manager.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart';

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

  // Initialize notification service
  await NotificationService.initialize();

  // Check icon state on app start
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await IconManager.checkAndUpdateIcon(user.uid);
    // Check for daily session reminder
    await NotificationService.checkAndShowDailyReminder();
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _hasShownNotificationThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetNotificationFlag();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 App lifecycle state changed to: $state');
  }

  void _resetNotificationFlag() {
    _hasShownNotificationThisSession = false;
    print('🔄 Reset notification flag for new session');
  }

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
            _resetNotificationFlag(); // Reset notification flag for new user session
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
      // Check for daily session reminder when user logs in
      await NotificationService.checkAndShowDailyReminder();
    } catch (e) {
      print('Error checking icon for user: $e');
    }
  }
}