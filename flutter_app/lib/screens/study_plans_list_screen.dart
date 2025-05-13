import 'package:flutter/material.dart';
import '../widgets/custom_scaffold.dart';
import '../services/firestore_service.dart';
import 'study_planner_settings_screen.dart';

class StudyPlansListScreen extends StatefulWidget {
  @override
  _StudyPlansListScreenState createState() => _StudyPlansListScreenState();
}

class _StudyPlansListScreenState extends State<StudyPlansListScreen> {
  List<Map<String, dynamic>>? studyPlans;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudyPlans();
  }

  Future<void> fetchStudyPlans() async {
    final sessions = await FirestoreService.getStudySessions();
    setState(() {
      studyPlans = sessions;
      isLoading = false;
    });
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
          : (studyPlans == null || studyPlans!.isEmpty)
          ? Center(child: Text('No study plans available.'))
          : ListView.builder(
        itemCount: studyPlans!.length,
        itemBuilder: (context, index) {
          final plan = studyPlans![index];
          return ListTile(
            title: Text(plan['sessionName'] ?? 'Unnamed Session'),
            subtitle: Text("Deadline: ${plan['examDeadline'] ?? 'N/A'}"),
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
