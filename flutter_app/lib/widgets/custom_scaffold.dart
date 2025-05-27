import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Color appBarColor;
  final Widget? floatingActionButton;
  final bool showBackButton;

  const CustomScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.appBarColor = Colors.lightBlue,
    this.floatingActionButton,
    this.showBackButton = true,
  }) : super(key: key);

  void _logout(BuildContext context) async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: Text(title),
        leading: showBackButton ? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ) : null,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Profile'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user != null) ...[
                          if (user.photoURL != null)
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(user.photoURL!),
                            )
                          else
                            CircleAvatar(
                              radius: 30,
                              child: Icon(Icons.person, size: 30),
                            ),
                          SizedBox(height: 16),
                          Text('Email: ${user.email ?? "No email"}'),
                          if (user.displayName != null)
                            Text('Name: ${user.displayName}'),
                        ] else
                          Text('Not signed in'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                      if (user != null)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _logout(context);
                          },
                          child: Text('Sign Out'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).primaryColor,
                child: user?.photoURL != null
                    ? ClipOval(
                        child: Image.network(
                          user!.photoURL!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
