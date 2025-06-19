import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/exam_dashboard_screen.dart';
import '../screens/day_summary_screen.dart';
import '../screens/study_plans_list_screen.dart';
import '../screens/mascot_screen.dart';
import '../screens/summary_screen.dart';

class CustomScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Color appBarColor;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final PreferredSizeWidget? customAppBar;

  const CustomScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.appBarColor = Colors.lightBlue,
    this.floatingActionButton,
    this.showBackButton = true,
    this.customAppBar,
  }) : super(key: key);

  void _logout(BuildContext context) async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Helper to get the current route name
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    // Helper: get first planId and uid for Mascot/Summary (for demo, real app should pass these)
    String? planId;
    String? uid = user?.uid;
    // TODO: In a real app, pass planId/uid from parent or via provider

    // Bottom navigation bar widget
    Widget bottomNavBar = Container(
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
              );
            },
            child: _NavBarItem(
              icon: Icons.home,
              label: "Home",
            ),
          ),
          // Mascot
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => MascotScreen()),
              );
            },
            child: _NavBarItem(
              icon: Icons.emoji_emotions,
              label: "Rank",
            ),
          ),
          // Summary
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SummaryScreen()),
              );
            },
            child: _NavBarItem(
              icon: Icons.assignment,
              label: "Summary",
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: customAppBar ?? AppBar(
        backgroundColor: appBarColor,
        title: Text(title),
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton ? null : Container(),
        actions: [
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
                          onPressed: () async {
                            Navigator.pop(context);
                            await AuthService.signOut();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                            );
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
      bottomNavigationBar: bottomNavBar,
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _NavBarItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
