import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_scaffold.dart';
import '../services/firestore_service.dart';
import 'study_planner_settings_screen.dart';
import 'session_screen.dart';

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
    return CustomScaffold(
      title: 'My Study Plans',
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Error: $error'))
              : studyPlans.isEmpty
                  ? Center(child: Text('No study plans available.'))
                  : ListView.builder(
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
                            child: isConfirmingEdit
                                ? SizedBox()
                                : Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: isConfirmingDelete
                                ? SizedBox()
                                : Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              setState(() {
                                isConfirmingEdit = true;
                              });
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Edit Study Plan'),
                                    content: Text('Do you want to edit this study plan?'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            isConfirmingEdit = false;
                                          });
                                          Navigator.of(context).pop(false);
                                        },
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            isConfirmingEdit = false;
                                          });
                                          Navigator.of(context).pop(true);
                                        },
                                        child: Text('Edit'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirm == true) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudyPlannerSettingsScreen(
                                      existingPlan: plan,
                                    ),
                                  ),
                                ).then((_) => fetchStudyPlans());
                              }
                              return false;
                            } else {
                              setState(() {
                                isConfirmingDelete = true;
                              });
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Delete Study Plan'),
                                    content: Text('Are you sure you want to delete this study plan?'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            isConfirmingDelete = false;
                                          });
                                          Navigator.of(context).pop(false);
                                        },
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            isConfirmingDelete = false;
                                          });
                                          Navigator.of(context).pop(true);
                                        },
                                        child: Text('Delete'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              return confirm ?? false;
                            }
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart && plan['id'] != null) {
                              deleteStudyPlan(plan['id']);
                            }
                          },
                          child: Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SessionScreen(sessionData: plan),
                                  ),
                                );
                              },
                              child: ListTile(
                                title: Text(
                                  plan['sessionName'] ?? 'Unnamed Session',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Deadline: ${formatDeadline(plan['examDeadline'])}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToAddPlan,
        child: Icon(Icons.add),
      ),
    );
  }
}
