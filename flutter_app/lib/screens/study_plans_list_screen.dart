import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_scaffold.dart';
import '../services/firestore_service.dart';
import 'study_planner_settings_screen.dart';

class StudyPlansListScreen extends StatefulWidget {
  @override
  _StudyPlansListScreenState createState() => _StudyPlansListScreenState();
}

class _StudyPlansListScreenState extends State<StudyPlansListScreen> {
  List<Map<String, dynamic>> studyPlans = [];
  bool isLoading = true;
  String? error;

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
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(
                              plan['sessionName'] ?? 'Unnamed Session',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deadline: ${formatDeadline(plan['examDeadline'])}'),
                                Text('Sessions per day: ${plan['sessionsPerDay']}'),
                                Text('Session length: ${plan['sessionLength']} minutes'),
                              ],
                            ),
                            isThreeLine: true,
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
