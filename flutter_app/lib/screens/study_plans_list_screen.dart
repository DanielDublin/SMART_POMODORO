import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_scaffold.dart';
import '../services/firestore_service.dart';
import '../services/mock_data_service.dart';
import 'study_planner_settings_screen.dart';
import 'session_screen.dart';
import 'exam_dashboard_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class StudyPlansListScreen extends StatefulWidget {
  @override
  _StudyPlansListScreenState createState() => _StudyPlansListScreenState();
}

class _StudyPlansListScreenState extends State<StudyPlansListScreen> {
  List<Map<String, dynamic>> studyPlans = [];
  bool isLoading = true;
  String? error;
  bool isConfirmingDelete = false;
  bool isConfirmingEdit = false;
  bool isGeneratingMockData = false;

  @override
  void initState() {
    super.initState();
    fetchStudyPlans();
  }

  Future<void> fetchStudyPlans() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      
      final sessions = await FirestoreService.getStudySessions();
      setState(() {
        studyPlans = sessions;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> generateMockData() async {
    setState(() {
      isGeneratingMockData = true;
    });

    try {
      await MockDataService().generateMockLogsForCurrentUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mock data generation completed'),
          backgroundColor: Colors.green,
        ),
      );
      await fetchStudyPlans();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating mock data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isGeneratingMockData = false;
      });
    }
  }

  Future<void> deleteStudyPlan(String planId) async {
    try {
      await FirestoreService.deleteStudySession(planId);
      await fetchStudyPlans(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Study plan deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete study plan: $e')),
      );
    }
  }

  String formatDeadline(dynamic deadline) {
    if (deadline == null) return 'No deadline set';
    try {
      if (deadline is Timestamp) {
        return DateFormat('dd/MM/yy').format(deadline.toDate());
      }
      return 'Invalid date';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void navigateToAddPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyPlannerSettingsScreen()),
    );
    await fetchStudyPlans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        leading: null,
        title: Text('My Study Plans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
          Builder(
            builder: (context) {
              final user = FirebaseAuth.instance.currentUser;
              return IconButton(
                icon: user?.photoURL != null
                    ? CircleAvatar(backgroundImage: NetworkImage(user!.photoURL!), radius: 16)
                    : Icon(Icons.account_circle, color: Colors.white, size: 32),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Profile'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user?.photoURL != null)
                            CircleAvatar(backgroundImage: NetworkImage(user!.photoURL!), radius: 32),
                          if (user?.displayName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(user!.displayName!, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          if (user?.email != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(user!.email!, style: TextStyle(color: Colors.grey[700])),
                            ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Error: $error'))
              : studyPlans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 80, color: Colors.grey[300]),
                          SizedBox(height: 24),
                          Text(
                            'No study plans available.',
                            style: TextStyle(fontSize: 18, color: Colors.blueGrey[700]),
                          ),
                          SizedBox(height: 32),
                          SizedBox(
                            width: 220,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.add, color: Colors.red),
                              label: Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: navigateToAddPlan,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: studyPlans.length,
                            itemBuilder: (context, index) {
                              final plan = studyPlans[index];
                              return Dismissible(
                                key: Key(plan['id'] ?? index.toString()),
                                direction: DismissDirection.horizontal,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: EdgeInsets.only(left: 20),
                                  color: Colors.blue,
                                  child: Icon(Icons.edit, color: Colors.white),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    final bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Edit Study Plan'),
                                          content: Text('Do you want to edit this study plan?'),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('Edit'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudyPlannerSettingsScreen(existingPlan: plan),
                                        ),
                                      ).then((_) => fetchStudyPlans());
                                    }
                                    return false;
                                  } else {
                                    final bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Delete Study Plan'),
                                          content: Text('Are you sure you want to delete this study plan?'),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('Delete'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true && plan['id'] != null) {
                                      await FirestoreService.deleteStudySession(plan['id']);
                                      await fetchStudyPlans();
                                    }
                                    return false;
                                  }
                                },
                                child: Card(
                                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () async {
                                      final currentUser = FirebaseAuth.instance.currentUser;
                                      if (currentUser != null && plan['id'] != null && plan['id'] != '') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExamDashboardScreen(
                                              uid: currentUser.uid,
                                              planId: plan['id'],
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: Missing user or plan ID')),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListTile(
                                      leading: Icon(Icons.menu_book, color: Colors.red, size: 32),
                                      title: Text(
                                        plan['sessionName'] ?? 'Unnamed Session',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      subtitle: Text(
                                        'Deadline: ${formatDeadline(plan['examDeadline'])}',
                                        style: TextStyle(color: Colors.blueGrey[700]),
                                      ),
                                      trailing: Icon(Icons.arrow_forward_ios, color: Colors.red),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          width: 220,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add, color: Colors.red),
                            label: Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: navigateToAddPlan,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
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
