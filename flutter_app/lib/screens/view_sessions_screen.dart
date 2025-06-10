import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewSessionsScreen extends StatefulWidget {
  final String uid;
  final String planId;
  const ViewSessionsScreen({required this.uid, required this.planId, Key? key}) : super(key: key);

  @override
  State<ViewSessionsScreen> createState() => _ViewSessionsScreenState();
}

class _ViewSessionsScreenState extends State<ViewSessionsScreen> {
  late Future<List<Map<String, dynamic>>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = fetchSessions();
  }

  Future<List<Map<String, dynamic>>> fetchSessions() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('session_logs')
        .where('sessionPlanId', isEqualTo: widget.planId)
        .get();

    final sessions = snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    sessions.sort((a, b) =>
      (b['startTime'] as Timestamp).compareTo(a['startTime'] as Timestamp));
    return sessions;
  }

  void _editSessionDialog(Map<String, dynamic> session) async {
    DateTime tempStartTime = (session['startTime'] as Timestamp).toDate();
    DateTime tempEndTime = (session['endTime'] as Timestamp).toDate();
    String? tempStatus = session['status'];
    String? tempSessionType = session['sessionType'];
    final durationController = TextEditingController(text: session['duration']?.toString() ?? '');

    // Use a valueNotifier to update the dialog's state outside of setStateDialog when time is picked.
    final ValueNotifier<DateTime> startTimeNotifier = ValueNotifier(tempStartTime);
    final ValueNotifier<DateTime> endTimeNotifier = ValueNotifier(tempEndTime);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Edit Session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date Picker for both start and end times
                  ListTile(
                    title: Text('Date: ${DateFormat('yyyy-MM-dd').format(startTimeNotifier.value)}'),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: startTimeNotifier.value,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          // Update both start and end dates, keeping original times
                          startTimeNotifier.value = DateTime(
                            pickedDate.year, pickedDate.month, pickedDate.day,
                            startTimeNotifier.value.hour, startTimeNotifier.value.minute,
                          );
                          endTimeNotifier.value = DateTime(
                            pickedDate.year, pickedDate.month, pickedDate.day,
                            endTimeNotifier.value.hour, endTimeNotifier.value.minute,
                          );
                        });
                      }
                    },
                  ),
                  // Start Time Picker (only hour and minute)
                  ListenableBuilder(
                    listenable: startTimeNotifier,
                    builder: (context, child) {
                      return ListTile(
                        title: Text('Start Time: ${DateFormat('HH:mm').format(startTimeNotifier.value)}'),
                        trailing: Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startTimeNotifier.value),
                          );
                          if (pickedTime != null) {
                            startTimeNotifier.value = DateTime(
                              startTimeNotifier.value.year,
                              startTimeNotifier.value.month,
                              startTimeNotifier.value.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          }
                        },
                      );
                    },
                  ),
                  // End Time Picker (only hour and minute)
                  ListenableBuilder(
                    listenable: endTimeNotifier,
                    builder: (context, child) {
                      return ListTile(
                        title: Text('End Time: ${DateFormat('HH:mm').format(endTimeNotifier.value)}'),
                        trailing: Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endTimeNotifier.value),
                          );
                          if (pickedTime != null) {
                            endTimeNotifier.value = DateTime(
                              endTimeNotifier.value.year,
                              endTimeNotifier.value.month,
                              endTimeNotifier.value.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          }
                        },
                      );
                    },
                  ),
                  TextField(
                    controller: durationController,
                    decoration: InputDecoration(labelText: 'Duration (min)'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    value: tempStatus,
                    decoration: InputDecoration(labelText: 'Status'),
                    items: ['completed', 'incompleted']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (newValue) {
                      setStateDialog(() {
                        tempStatus = newValue;
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: tempSessionType,
                    decoration: InputDecoration(labelText: 'Session Type'),
                    items: ['study', 'short break', 'long break']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (newValue) {
                      setStateDialog(() {
                        tempSessionType = newValue;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Return false on cancel
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (endTimeNotifier.value.isBefore(startTimeNotifier.value)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('End time must be after start time')),
                    );
                    return;
                  }
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.uid)
                      .collection('session_logs')
                      .doc(session['id'])
                      .update({
                    'duration': int.tryParse(durationController.text) ?? session['duration'],
                    'status': tempStatus,
                    'sessionType': tempSessionType,
                    'startTime': Timestamp.fromDate(startTimeNotifier.value),
                    'endTime': Timestamp.fromDate(endTimeNotifier.value),
                  });
                  Navigator.pop(context, true); // Return true on save
                },
                child: Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red), // Add button style
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        _sessionsFuture = fetchSessions(); // Refresh list only if saved
      });
    }
  }

  void _deleteSession(String sessionId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('session_logs')
        .doc(sessionId)
        .delete();
    setState(() {
      _sessionsFuture = fetchSessions();
    });
  }

  void _addSessionDialog() async {
    DateTime tempStartTime = DateTime.now();
    DateTime tempEndTime = DateTime.now().add(Duration(minutes: 25));
    String? tempStatus = 'completed'; // Default status
    String? tempSessionType = 'study'; // Default session type
    final durationController = TextEditingController();

    final ValueNotifier<DateTime> startTimeNotifier = ValueNotifier(tempStartTime);
    final ValueNotifier<DateTime> endTimeNotifier = ValueNotifier(tempEndTime);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update dialog content
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Add Session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Date: ${DateFormat('yyyy-MM-dd').format(startTimeNotifier.value)}'),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: startTimeNotifier.value,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          startTimeNotifier.value = DateTime(
                            pickedDate.year, pickedDate.month, pickedDate.day,
                            startTimeNotifier.value.hour, startTimeNotifier.value.minute,
                          );
                          endTimeNotifier.value = DateTime(
                            pickedDate.year, pickedDate.month, pickedDate.day,
                            endTimeNotifier.value.hour, endTimeNotifier.value.minute,
                          );
                        });
                      }
                    },
                  ),
                  ListenableBuilder(
                    listenable: startTimeNotifier,
                    builder: (context, child) {
                      return ListTile(
                        title: Text('Start Time: ${DateFormat('HH:mm').format(startTimeNotifier.value)}'),
                        trailing: Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startTimeNotifier.value),
                          );
                          if (pickedTime != null) {
                            startTimeNotifier.value = DateTime(
                              startTimeNotifier.value.year,
                              startTimeNotifier.value.month,
                              startTimeNotifier.value.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          }
                        },
                      );
                    },
                  ),
                  ListenableBuilder(
                    listenable: endTimeNotifier,
                    builder: (context, child) {
                      return ListTile(
                        title: Text('End Time: ${DateFormat('HH:mm').format(endTimeNotifier.value)}'),
                        trailing: Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endTimeNotifier.value),
                          );
                          if (pickedTime != null) {
                            endTimeNotifier.value = DateTime(
                              endTimeNotifier.value.year,
                              endTimeNotifier.value.month,
                              endTimeNotifier.value.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          }
                        },
                      );
                    },
                  ),
                  TextField(
                    controller: durationController,
                    decoration: InputDecoration(labelText: 'Duration (min)'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    value: tempStatus,
                    decoration: InputDecoration(labelText: 'Status'),
                    items: ['completed', 'incompleted']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (newValue) {
                      setStateDialog(() {
                        tempStatus = newValue;
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: tempSessionType,
                    decoration: InputDecoration(labelText: 'Session Type'),
                    items: ['study', 'short break', 'long break']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (newValue) {
                      setStateDialog(() {
                        tempSessionType = newValue;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Return false on cancel
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (endTimeNotifier.value.isBefore(startTimeNotifier.value)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('End time must be after start time')),
                    );
                    return;
                  }
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.uid)
                      .collection('session_logs')
                      .add({
                    'duration': int.tryParse(durationController.text) ?? 25,
                    'status': tempStatus,
                    'sessionType': tempSessionType,
                    'startTime': Timestamp.fromDate(startTimeNotifier.value),
                    'endTime': Timestamp.fromDate(endTimeNotifier.value),
                    'sessionPlanId': widget.planId,
                    'uid': widget.uid,
                  });
                  Navigator.pop(context, true); // Return true on save
                },
                child: Text('Add'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red), // Add button style
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        _sessionsFuture = fetchSessions(); // Refresh list only if saved
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('View & Edit Sessions')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSessionDialog,
        child: Icon(Icons.add),
        tooltip: 'Add Session',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return Center(child: Text('No sessions found for this plan.'));
          }
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final startTime = (session['startTime'] as Timestamp).toDate();
              final endTime = (session['endTime'] as Timestamp).toDate();
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Session: ${session['sessionType'] ?? 'study'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration: ${session['duration']} min'),
                      Text('Status: ${session['status']}'),
                      Text('Start: ${DateFormat('yyyy-MM-dd HH:mm').format(startTime)}'),
                      Text('End: ${DateFormat('yyyy-MM-dd HH:mm').format(endTime)}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _editSessionDialog(session),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteSession(session['id']),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 