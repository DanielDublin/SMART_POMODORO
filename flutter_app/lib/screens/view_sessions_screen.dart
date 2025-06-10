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
    final durationController = TextEditingController(text: session['duration']?.toString() ?? '');
    final statusController = TextEditingController(text: session['status'] ?? '');
    final sessionTypeController = TextEditingController(text: session['sessionType'] ?? '');
    final startTime = (session['startTime'] as Timestamp).toDate();
    final endTime = (session['endTime'] as Timestamp).toDate();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Start: ${DateFormat('yyyy-MM-dd HH:mm').format(startTime)}'),
              Text('End: ${DateFormat('yyyy-MM-dd HH:mm').format(endTime)}'),
              TextField(
                controller: durationController,
                decoration: InputDecoration(labelText: 'Duration (min)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: statusController,
                decoration: InputDecoration(labelText: 'Status'),
              ),
              TextField(
                controller: sessionTypeController,
                decoration: InputDecoration(labelText: 'Session Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .collection('session_logs')
                  .doc(session['id'])
                  .update({
                'duration': int.tryParse(durationController.text) ?? session['duration'],
                'status': statusController.text,
                'sessionType': sessionTypeController.text,
              });
              Navigator.pop(context);
              setState(() {
                _sessionsFuture = fetchSessions();
              });
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
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
    final durationController = TextEditingController();
    final statusController = TextEditingController();
    final sessionTypeController = TextEditingController();
    DateTime? startTime;
    DateTime? endTime;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: durationController,
                decoration: InputDecoration(labelText: 'Duration (min)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: statusController,
                decoration: InputDecoration(labelText: 'Status'),
              ),
              TextField(
                controller: sessionTypeController,
                decoration: InputDecoration(labelText: 'Session Type'),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) startTime = picked;
                },
                child: Text('Pick Start Date'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) endTime = picked;
                },
                child: Text('Pick End Date'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (startTime == null || endTime == null) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .collection('session_logs')
                  .add({
                'duration': int.tryParse(durationController.text) ?? 25,
                'status': statusController.text,
                'sessionType': sessionTypeController.text,
                'startTime': Timestamp.fromDate(startTime!),
                'endTime': Timestamp.fromDate(endTime!),
                'sessionPlanId': widget.planId,
                'uid': widget.uid,
              });
              Navigator.pop(context);
              setState(() {
                _sessionsFuture = fetchSessions();
              });
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
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