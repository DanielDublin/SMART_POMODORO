import 'package:flutter/material.dart';
import 'study_planner_settings_screen.dart';
import '../widgets/custom_scaffold.dart';

class StudyPlansListScreen extends StatefulWidget {
  @override
  _StudyPlansListScreenState createState() => _StudyPlansListScreenState();
}

class _StudyPlansListScreenState extends State<StudyPlansListScreen> {
  List<String> studyPlans = []; // Replace with real data from Firestore later

  void navigateToAddPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyPlannerSettingsScreen()),
    );
    // Refresh list here if necessary (e.g., fetch updated plans)
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
        title: 'My Study Plans',
      body: studyPlans.isEmpty
          ? Center(child: Text('No study plans available.'))
          : ListView.builder(
        itemCount: studyPlans.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(studyPlans[index]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToAddPlan,
        child: Icon(Icons.add),
      ),
    );
  }
}
