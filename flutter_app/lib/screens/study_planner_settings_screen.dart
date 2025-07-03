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
  int _sessionsPerDay = 4;
  int _pomodoroLength = 25;
  int _shortBreakLength = 5;
  int _longBreakLength = 10;
  int _numberOfPomodoros = 4;
  Set<DateTime> _selectedDays = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _firstDay = DateTime.now();
  DateTime _lastDay = DateTime.now().add(Duration(days: 365));

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _studySessionNameController.text = widget.existingPlan!['sessionName'] ?? '';
      _examDeadline = (widget.existingPlan!['examDeadline'] as Timestamp).toDate();
      _sessionsPerDay = widget.existingPlan!['sessionsPerDay'] ?? 4;
      _pomodoroLength = widget.existingPlan!['pomodoroLength'] ?? 25;
      _shortBreakLength = widget.existingPlan!['shortBreakLength'] ?? 5;
      _longBreakLength = widget.existingPlan!['longBreakLength'] ?? 10;
      _numberOfPomodoros = widget.existingPlan!['numberOfPomodoros'] ?? 4;
      if (widget.existingPlan!['selectedDays'] != null) {
        _selectedDays = (widget.existingPlan!['selectedDays'] as List)
            .map((timestamp) => DateTime((timestamp as Timestamp).toDate().year,
                                          (timestamp as Timestamp).toDate().month,
                                          (timestamp as Timestamp).toDate().day))
            .toSet();
      }
      _lastDay = _examDeadline ?? DateTime.now().add(Duration(days: 365));

      // Calculate _firstDay to include past selected dates if any
      if (_selectedDays.isNotEmpty) {
        final earliestSelectedDay = _selectedDays.reduce((a, b) => a.isBefore(b) ? a : b);
        _firstDay = DateTime(earliestSelectedDay.year, earliestSelectedDay.month, 1);
      } else {
        _firstDay = DateTime(DateTime.now().year, DateTime.now().month, 1);
      }
      // Ensure _selectedDays are normalized in initState as well
      _selectedDays = _selectedDays.map((d) => DateTime(d.year, d.month, d.day)).toSet();
      debugPrint('InitState - _selectedDays: $_selectedDays');
      debugPrint('InitState - _firstDay: $_firstDay');
      debugPrint('InitState - _examDeadline: $_examDeadline');
    }
  }

  void _showNumberPicker({
    required String title,
    required int value,
    required int min,
    required int max,
    required Function(int) onChanged,
    String? unit,
  }) {
    int tempValue = value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  setStateDialog(() {
                    if (tempValue > min) tempValue--;
                  });
                },
              ),
              SizedBox(width: 8),
              Text('$tempValue', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              if (unit != null) ...[
                SizedBox(width: 4),
                Text(unit, style: TextStyle(fontSize: 16)),
              ],
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add_circle, color: Colors.red),
                onPressed: () {
                  setStateDialog(() {
                    if (tempValue < max) tempValue++;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onChanged(tempValue);
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showExamDeadlinePicker() async {
    DateTime tempSelectedDay = _examDeadline ?? DateTime.now();
    DateTime tempFocusedDay = tempSelectedDay;
    DateTime firstDay = DateTime.now();
    DateTime lastDay = DateTime(2100);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Exam Deadline', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.infinity,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setStateDialog) => TableCalendar(
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: tempFocusedDay,
              selectedDayPredicate: (day) {
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return normalizedDay == DateTime(tempSelectedDay.year, tempSelectedDay.month, tempSelectedDay.day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setStateDialog(() {
                  tempSelectedDay = selectedDay;
                  tempFocusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.all(6.0),
                defaultTextStyle: TextStyle(color: Colors.black, fontSize: 14),
                weekendTextStyle: TextStyle(color: Colors.black, fontSize: 14),
                selectedDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                disabledDecoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.black),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.black, fontSize: 12),
                weekendStyle: TextStyle(color: Colors.black, fontSize: 12),
              ),
              calendarFormat: CalendarFormat.month,
              enabledDayPredicate: (day) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                // Disable days before today
                if (day.isBefore(today)) {
                  return false;
                }
                return true;
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _examDeadline = DateTime(tempSelectedDay.year, tempSelectedDay.month, tempSelectedDay.day);
                _lastDay = _examDeadline!;
                _selectedDays.clear();
              });
              Navigator.pop(context);
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDaysPicker() async {
    Set<DateTime> tempSelectedDays = Set.from(_selectedDays.map((d) => DateTime(d.year, d.month, d.day)));
    DateTime tempFocusedDay = _focusedDay;

    if (tempSelectedDays.isNotEmpty) {
      final earliestSelectedDay = tempSelectedDays.reduce((a, b) => a.isBefore(b) ? a : b);
      tempFocusedDay = DateTime(earliestSelectedDay.year, earliestSelectedDay.month, 1);
    } else {
      tempFocusedDay = DateTime(DateTime.now().year, DateTime.now().month, 1);
    }

    // Ensure tempFocusedDay is not before _firstDay
    if (tempFocusedDay.isBefore(_firstDay)) {
      tempFocusedDay = _firstDay;
    }

    debugPrint('ShowDaysPicker - tempSelectedDays before dialog: $tempSelectedDays');
    debugPrint('ShowDaysPicker - tempFocusedDay before dialog: $tempFocusedDay');
    debugPrint('ShowDaysPicker - _firstDay: $_firstDay');
    debugPrint('ShowDaysPicker - _lastDay: $_lastDay');
    debugPrint('ShowDaysPicker - _examDeadline: $_examDeadline');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Days to Study', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.infinity,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setStateDialog) => TableCalendar(
              firstDay: _firstDay,
              lastDay: _lastDay,
              focusedDay: tempFocusedDay,
              selectedDayPredicate: (day) {
                // Normalize the day passed by TableCalendar before checking containment
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return tempSelectedDays.contains(normalizedDay);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setStateDialog(() {
                  tempFocusedDay = focusedDay;
                  final normalizedSelectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  if (tempSelectedDays.contains(normalizedSelectedDay)) {
                    tempSelectedDays.remove(normalizedSelectedDay);
                  } else {
                    tempSelectedDays.add(normalizedSelectedDay);
                  }
                });
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.all(6.0),
                defaultTextStyle: TextStyle(color: Colors.black, fontSize: 14),
                weekendTextStyle: TextStyle(color: Colors.black, fontSize: 14),
                selectedDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                disabledDecoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.black, fontSize: 12),
                weekendStyle: TextStyle(color: Colors.black, fontSize: 12),
              ),
              calendarFormat: CalendarFormat.month,
              enabledDayPredicate: (day) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day); // Normalized today

                // Disable days before today
                if (day.isBefore(today)) {
                  return false;
                }

                // Disable days after exam deadline
                if (_examDeadline != null) {
                  final deadlineDate = DateTime(_examDeadline!.year, _examDeadline!.month, _examDeadline!.day);
                  if (day.isAfter(deadlineDate)) {
                    return false;
                  }
                }
                return true; // Enable all other days
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _selectedDays = tempSelectedDays.map((d) => DateTime(d.year, d.month, d.day)).toSet();
                _focusedDay = tempFocusedDay;
              });
              Navigator.pop(context);
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
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
        'sessionsPerDay': _sessionsPerDay,
        'selectedDays': _selectedDays.map((date) => Timestamp.fromDate(date)).toList(),
        'pomodoroLength': _pomodoroLength,
        'shortBreakLength': _shortBreakLength,
        'longBreakLength': _longBreakLength,
        'numberOfPomodoros': _numberOfPomodoros,
        'isActive': true,
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

  String _daysSummary() {
    if (_selectedDays.isEmpty) return 'No days selected';
    final sorted = _selectedDays.toList()..sort();
    return sorted.map((d) => DateFormat('dd/MM').format(d)).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        title: Text('New Study Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 370,
            margin: EdgeInsets.symmetric(vertical: 24),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _studySessionNameController,
                    decoration: InputDecoration(
                      hintText: "Plan Name (e.g., 'Exam Prep - Calculus')",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  _SettingsTile(
                    icon: Icons.calendar_today,
                    label: 'Exam Deadline',
                    value: _examDeadline == null ? 'DD/MM/YY' : DateFormat('dd/MM/yy').format(_examDeadline!),
                    onTap: _showExamDeadlinePicker,
                  ),
                  _SettingsTile(
                    icon: Icons.calendar_month,
                    label: 'Days to Study',
                    value: _selectedDays.isEmpty ? 'No days selected' : '',
                    customValueWidget: _selectedDays.isEmpty
                        ? null
                        : Container(
                            constraints: BoxConstraints(maxWidth: 180),
                            child: Text(
                              _daysSummary(),
                              style: TextStyle(fontSize: 16, color: Colors.red),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    onTap: _examDeadline == null ? null : _showDaysPicker,
                  ),
                  _SettingsTile(
                    icon: Icons.repeat,
                    label: 'Sessions Per Day',
                    value: '$_sessionsPerDay',
                    onTap: () => _showNumberPicker(
                      title: 'Sessions Per Day',
                      value: _sessionsPerDay,
                      min: 1,
                      max: 10,
                      onChanged: (v) => setState(() => _sessionsPerDay = v),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.timer,
                    label: 'Pomodoro Length',
                    value: '$_pomodoroLength minutes',
                    onTap: () => _showNumberPicker(
                      title: 'Pomodoro Length (minutes)',
                      value: _pomodoroLength,
                      min: 1,
                      max: 90,
                      onChanged: (v) => setState(() => _pomodoroLength = v),
                      unit: 'min',
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.repeat_on,
                    label: 'Number of Pomodoros',
                    value: '$_numberOfPomodoros',
                    onTap: () => _showNumberPicker(
                      title: 'Number of Pomodoros',
                      value: _numberOfPomodoros,
                      min: 1,
                      max: 10,
                      onChanged: (v) => setState(() => _numberOfPomodoros = v),
                      unit: 'pomodoros',
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.free_breakfast,
                    label: 'Short Break Duration',
                    value: '$_shortBreakLength minutes',
                    onTap: () => _showNumberPicker(
                      title: 'Short Break Duration (minutes)',
                      value: _shortBreakLength,
                      min: 1,
                      max: 30,
                      onChanged: (v) => setState(() => _shortBreakLength = v),
                      unit: 'min',
                    ),
                  ),
              _SettingsTile(
                icon: Icons.free_breakfast,
                label: 'Long Break Duration',
                value: '$_longBreakLength minutes',
                onTap: () => _showNumberPicker(
                  title: 'Long Break Duration (minutes)',
                  value: _longBreakLength,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setState(() => _longBreakLength = v),
                  unit: 'min',
                ),
              ),
                  SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? customValueWidget;
  const _SettingsTile({required this.icon, required this.label, this.value = '', this.onTap, this.customValueWidget});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.red, size: 28),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      trailing: customValueWidget ?? Text(value, style: TextStyle(fontSize: 16, color: Colors.red)),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: Colors.grey[100],
      dense: true,
    );
  }
}
