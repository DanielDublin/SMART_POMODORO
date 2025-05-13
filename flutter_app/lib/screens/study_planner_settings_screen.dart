import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'study_plans_list_screen.dart';

class StudyPlannerSettingsScreen extends StatefulWidget {
  @override
  _StudyPlannerSettingsScreenState createState() => _StudyPlannerSettingsScreenState();
}

class _StudyPlannerSettingsScreenState extends State<StudyPlannerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studySessionNameController = TextEditingController();
  DateTime? _examDeadline;
  final _sessionsPerDayController = TextEditingController();
  final _sessionLengthController = TextEditingController();
  final _longBreakAfterController = TextEditingController();
  final _longBreakDurationController = TextEditingController();
  final _shortBreakDurationController = TextEditingController();

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _examDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _examDeadline = pickedDate;
      });
    }
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final sessionData = {
        'sessionName': _studySessionNameController.text.trim(),
        'examDeadline': _examDeadline,
        'sessionsPerDay': int.tryParse(_sessionsPerDayController.text) ?? 0,
        'sessionLength': int.tryParse(_sessionLengthController.text) ?? 0,
        'longBreakAfter': int.tryParse(_longBreakAfterController.text) ?? 0,
        'longBreakDuration': int.tryParse(_longBreakDurationController.text) ?? 0,
        'shortBreakDuration': int.tryParse(_shortBreakDurationController.text) ?? 0,
      };
      try {
        await FirestoreService.saveStudySession(sessionData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings saved!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
      );
    }
  }

  @override
  void dispose() {
    _studySessionNameController.dispose();
    _sessionsPerDayController.dispose();
    _sessionLengthController.dispose();
    _longBreakAfterController.dispose();
    _longBreakDurationController.dispose();
    _shortBreakDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Study Planner Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _studySessionNameController,
                decoration: InputDecoration(hintText: 'Session Name',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey,),
                ),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Exam Deadline',
                      hintText: 'DD/MM/YY',
                    ),
                    controller: TextEditingController(
                      text: _examDeadline == null
                          ? ''
                          : DateFormat('dd/MM/yy').format(_examDeadline!),
                    ),
                  ),
                ),
              ),
              TextFormField(
                controller: _sessionsPerDayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Sessions Per Day'),
              ),
              TextFormField(
                controller: _sessionLengthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Session Length (minutes)'),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _longBreakAfterController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Long Break After (sessions)'),
                    ),
                    TextFormField(
                      controller: _longBreakDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Long Break Duration (minutes)'),
                    ),
                    TextFormField(
                      controller: _shortBreakDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Short Break Duration (minutes)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text('SAVE'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
