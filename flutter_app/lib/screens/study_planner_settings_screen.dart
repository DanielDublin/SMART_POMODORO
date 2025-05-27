import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class StudyPlannerSettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPlan;

  StudyPlannerSettingsScreen({this.existingPlan});

  @override
  _StudyPlannerSettingsScreenState createState() => _StudyPlannerSettingsScreenState();
}

class _StudyPlannerSettingsScreenState extends State<StudyPlannerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studySessionNameController = TextEditingController();
  DateTime? _examDeadline;
  final _sessionsPerDayController = TextEditingController(text: '3');
  final _pomodoroLengthController = TextEditingController(text: '25');
  final _shortBreakLengthController = TextEditingController(text: '5');
  final _longBreakLengthController = TextEditingController(text: '30');
  final _longBreakAfterController = TextEditingController(text: '4');
  
  // Calendar related variables
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  Set<DateTime> _selectedDays = {};
  DateTime _firstDay = DateTime.now();
  DateTime _lastDay = DateTime.now().add(Duration(days: 365));

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _studySessionNameController.text = widget.existingPlan!['sessionName'] ?? '';
      _examDeadline = (widget.existingPlan!['examDeadline'] as Timestamp).toDate();
      _sessionsPerDayController.text = (widget.existingPlan!['sessionsPerDay'] ?? 3).toString();
      _pomodoroLengthController.text = (widget.existingPlan!['pomodoroLength'] ?? 25).toString();
      _shortBreakLengthController.text = (widget.existingPlan!['shortBreakLength'] ?? 5).toString();
      _longBreakLengthController.text = (widget.existingPlan!['longBreakLength'] ?? 30).toString();
      _longBreakAfterController.text = (widget.existingPlan!['longBreakAfter'] ?? 4).toString();
      
      // Convert selected days from Timestamps to DateTime
      if (widget.existingPlan!['selectedDays'] != null) {
        _selectedDays = (widget.existingPlan!['selectedDays'] as List)
            .map((timestamp) => (timestamp as Timestamp).toDate())
            .toSet();
      }
      
      _lastDay = _examDeadline ?? DateTime.now().add(Duration(days: 365));
    }
  }

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
        _lastDay = pickedDate; // Update last day to exam deadline
        _selectedDays.clear(); // Clear previous selections
      });
    }
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      if (_studySessionNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session name is required')),
        );
        return;
      }

      if (_examDeadline == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exam deadline is required')),
        );
        return;
      }

      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one study day')),
        );
        return;
      }

      final sessionData = {
        'sessionName': _studySessionNameController.text.trim(),
        'examDeadline': _examDeadline,
        'sessionsPerDay': int.tryParse(_sessionsPerDayController.text) ?? 0,
        'selectedDays': _selectedDays.map((date) => Timestamp.fromDate(date)).toList(),
        'pomodoroLength': int.tryParse(_pomodoroLengthController.text) ?? 25,
        'shortBreakLength': int.tryParse(_shortBreakLengthController.text) ?? 5,
        'longBreakLength': int.tryParse(_longBreakLengthController.text) ?? 30,
        'longBreakAfter': int.tryParse(_longBreakAfterController.text) ?? 4,
      };

      try {
        if (widget.existingPlan != null) {
          await FirestoreService.updateStudySession(widget.existingPlan!['id'], sessionData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Study plan updated!')),
          );
        } else {
          await FirestoreService.saveStudySession(sessionData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Settings saved!')),
          );
        }
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPlan != null ? 'Edit Study Plan' : 'Study Planner Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Session Name
            TextFormField(
              controller: _studySessionNameController,
              decoration: InputDecoration(
                hintText: 'Session Name *',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
                errorStyle: TextStyle(color: Colors.red, fontSize: 16),
              ),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Session name is required';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            SizedBox(height: 20),

            // Plan Settings Section
            Text(
              'Plan Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            // Exam Deadline
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Exam Deadline *',
                    hintText: 'DD/MM/YY',
                    hintStyle: TextStyle(color: Colors.grey),
                    errorStyle: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  controller: TextEditingController(
                    text: _examDeadline == null
                        ? ''
                        : DateFormat('dd/MM/yy').format(_examDeadline!),
                  ),
                  validator: (value) {
                    if (_examDeadline == null) {
                      return 'Exam deadline is required';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
            ),

            // Sessions Per Day
            TextFormField(
              controller: _sessionsPerDayController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Sessions Per Day'),
            ),

            // Calendar for selecting study days - only show if exam deadline is set
            if (_examDeadline != null) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        'Days To Study (Before ${DateFormat('dd/MM/yy').format(_examDeadline!)})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TableCalendar(
                        firstDay: _firstDay,
                        lastDay: _lastDay,
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) => _selectedDays.contains(day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                            if (_selectedDays.contains(selectedDay)) {
                              _selectedDays.remove(selectedDay);
                            } else {
                              _selectedDays.add(selectedDay);
                            }
                          });
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          disabledDecoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (date.year == _examDeadline!.year &&
                                date.month == _examDeadline!.month &&
                                date.day == _examDeadline!.day) {
                              return Positioned(
                                bottom: 1,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                        enabledDayPredicate: (day) => day.isBefore(_examDeadline!),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 20),

            // Pomodoro Settings Section
            Text(
              'Pomodoro Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            // Pomodoro Settings Fields
            TextFormField(
              controller: _pomodoroLengthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Pomodoro Length (minutes)'),
            ),
            TextFormField(
              controller: _shortBreakLengthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Short Break Length (minutes)'),
            ),
            TextFormField(
              controller: _longBreakLengthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Long Break Length (minutes)'),
            ),
            TextFormField(
              controller: _longBreakAfterController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Long Break After (pomodoros)'),
            ),

            SizedBox(height: 20),
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
    );
  }

  @override
  void dispose() {
    _studySessionNameController.dispose();
    _sessionsPerDayController.dispose();
    _pomodoroLengthController.dispose();
    _shortBreakLengthController.dispose();
    _longBreakLengthController.dispose();
    _longBreakAfterController.dispose();
    super.dispose();
  }
}
