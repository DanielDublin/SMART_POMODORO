import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DaySummaryScreen extends StatefulWidget {
  final String uid;
  final String planId;
  final DateTime selectedDate;
  final int expectedSessions;
  final int pomodoroLength;
  final int numberOfPomodoros;

  const DaySummaryScreen({
    Key? key,
    required this.uid,
    required this.planId,
    required this.selectedDate,
    required this.expectedSessions,
    required this.pomodoroLength,
    required this.numberOfPomodoros,
  }) : super(key: key);

  @override
  _DaySummaryScreenState createState() => _DaySummaryScreenState();
}

class _DaySummaryScreenState extends State<DaySummaryScreen> {
  late Future<Map<String, dynamic>> _dayData;
  final _formKey = GlobalKey<FormState>();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _dayData = _fetchDayData();
  }

  Future<Map<String, dynamic>> _fetchDayData() async {
    final logsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('session_logs')
        .where('sessionPlanId', isEqualTo: widget.planId)
        .where('sessionType', isEqualTo: 'study')
        .get();

    final logs = List<Map<String, dynamic>>.from(logsSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Add document ID to the data
      return data;
    }));
    
    final startOfDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final endOfDay = startOfDay.add(Duration(days: 1));
    final filteredLogs = logs.where((log) {
      final startTime = (log['startTime'] as Timestamp).toDate();
      return startTime.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) && startTime.isBefore(endOfDay);
    }).toList();
    
    final expectedMinutes = widget.expectedSessions * widget.pomodoroLength * widget.numberOfPomodoros;
    final actualMinutes = filteredLogs.fold<int>(0, (sum, log) => sum + (log['duration'] as int? ?? 0));
    final completionPercentage = expectedMinutes > 0 ? (actualMinutes / expectedMinutes * 100).clamp(0.0, 100.0) : 0.0;

    return {
      'logs': filteredLogs,
      'expectedMinutes': expectedMinutes,
      'actualMinutes': actualMinutes,
      'completionPercentage': completionPercentage,
    };
  }

  Future<void> _updateSessionTime(String logId, DateTime newStartTime, DateTime newEndTime) async {
    // Get all sessions for this day
    final logsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('session_logs')
        .where('sessionPlanId', isEqualTo: widget.planId)
        .where('sessionType', isEqualTo: 'study')
        .get();

    final logs = logsSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).where((log) => log['id'] != logId).toList(); // Exclude current session

    // Filter logs for this day
    final dayLogs = logs.where((log) {
      final logStart = (log['startTime'] as Timestamp).toDate();
      return logStart.year == newStartTime.year && 
             logStart.month == newStartTime.month && 
             logStart.day == newStartTime.day;
    }).toList();

    // Find all overlapping sessions and merge them
    List<String> sessionsToDelete = [];
    DateTime mergedStartTime = newStartTime;
    DateTime mergedEndTime = newEndTime;

    for (var log in dayLogs) {
      final logStart = (log['startTime'] as Timestamp).toDate();
      final logEnd = (log['endTime'] as Timestamp).toDate();

      // Check if sessions overlap or are adjacent
      if (!(mergedEndTime.isBefore(logStart) || mergedStartTime.isAfter(logEnd))) {
        // Take the earliest start time and latest end time
        mergedStartTime = mergedStartTime.isBefore(logStart) ? mergedStartTime : logStart;
        mergedEndTime = mergedEndTime.isAfter(logEnd) ? mergedEndTime : logEnd;
        sessionsToDelete.add(log['id']);
      }
    }

    // Delete all overlapped sessions
    for (String id in sessionsToDelete) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('session_logs')
          .doc(id)
          .delete();
    }

    // Update the current session with merged times
    final duration = mergedEndTime.difference(mergedStartTime).inMinutes;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('session_logs')
        .doc(logId)
        .update({
      'startTime': Timestamp.fromDate(mergedStartTime),
      'endTime': Timestamp.fromDate(mergedEndTime),
      'duration': duration,
    });

    setState(() {
      _hasChanges = true;
      _dayData = _fetchDayData();
    });
  }

  Future<void> _addNewSession() async {
    TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    
    if (start != null) {
      TimeOfDay? end = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      
      if (end != null) {
        final startTime = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, start.hour, start.minute);
        final endTime = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, end.hour, end.minute);
        
        if (endTime.isAfter(startTime)) {
          // Get all sessions for this day
          final logsSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .collection('session_logs')
              .where('sessionPlanId', isEqualTo: widget.planId)
              .where('sessionType', isEqualTo: 'study')
              .get();

          final logs = logsSnap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Filter logs for this day
          final dayLogs = logs.where((log) {
            final logStart = (log['startTime'] as Timestamp).toDate();
            return logStart.year == startTime.year && 
                   logStart.month == startTime.month && 
                   logStart.day == startTime.day;
          }).toList();

          // Find all overlapping sessions and merge them
          List<String> sessionsToDelete = [];
          DateTime mergedStartTime = startTime;
          DateTime mergedEndTime = endTime;

          for (var log in dayLogs) {
            final logStart = (log['startTime'] as Timestamp).toDate();
            final logEnd = (log['endTime'] as Timestamp).toDate();

            // Check if sessions overlap or are adjacent
            if (!(mergedEndTime.isBefore(logStart) || mergedStartTime.isAfter(logEnd))) {
              // Take the earliest start time and latest end time
              mergedStartTime = mergedStartTime.isBefore(logStart) ? mergedStartTime : logStart;
              mergedEndTime = mergedEndTime.isAfter(logEnd) ? mergedEndTime : logEnd;
              sessionsToDelete.add(log['id']);
            }
          }

          // Delete all overlapped sessions
          for (String id in sessionsToDelete) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .collection('session_logs')
                .doc(id)
                .delete();
          }

          // Create new merged session
          final duration = mergedEndTime.difference(mergedStartTime).inMinutes;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .collection('session_logs')
              .add({
            'sessionPlanId': widget.planId,
            'sessionType': 'study',
            'startTime': Timestamp.fromDate(mergedStartTime),
            'endTime': Timestamp.fromDate(mergedEndTime),
            'duration': duration,
          });

          setState(() {
            _hasChanges = true;
            _dayData = _fetchDayData();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('End time must be after start time')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.red,
          elevation: 0,
          centerTitle: true,
          title: Text(
            DateFormat('dd.MM.yy').format(widget.selectedDate),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _dayData,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final logs = List<Map<String, dynamic>>.from(data['logs']);
            final expectedMinutes = data['expectedMinutes'];
            final actualMinutes = data['actualMinutes'];
            final completionPercentage = data['completionPercentage'];

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Daily Study Goal Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Daily Study Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Text('Expected', style: TextStyle(fontSize: 14, color: Colors.black87)),
                                    SizedBox(height: 4),
                                    Text('$expectedMinutes min', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Actual', style: TextStyle(fontSize: 14, color: Colors.red)),
                                    SizedBox(height: 4),
                                    Text('$actualMinutes min', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: expectedMinutes > 0 ? (actualMinutes / expectedMinutes).clamp(0.0, 1.0) : 0.0,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${completionPercentage.toStringAsFixed(0)}% of daily goal completed',
                              style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 18),
                    // Study Sessions Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Study Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            SizedBox(height: 16),
                            if (logs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'No study sessions recorded for this day',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            if (logs.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                  final log = logs[index];
                                  final startTime = (log['startTime'] as Timestamp).toDate();
                                  final endTime = (log['endTime'] as Timestamp).toDate();
                                  final duration = log['duration'] as int;
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 16),
                                    child: Card(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Session ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                Text('Duration: $duration min', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                                if (!widget.selectedDate.isAfter(DateTime.now()))
                                                  IconButton(
                                                    icon: Icon(Icons.delete, color: Colors.red),
                                                    tooltip: 'Delete Session',
                                                    onPressed: () async {
                                                      await FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(widget.uid)
                                                        .collection('session_logs')
                                                        .doc(log['id'])
                                                        .delete();
                                                      setState(() {
                                                        _hasChanges = true;
                                                        _dayData = _fetchDayData();
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Start Time', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                                      SizedBox(height: 4),
                                                      OutlinedButton.icon(
                                                        style: OutlinedButton.styleFrom(
                                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        onPressed: () async {
                                                          final newStartTime = await showTimePicker(
                                                            context: context,
                                                            initialTime: TimeOfDay.fromDateTime(startTime),
                                                            builder: (context, child) {
                                                              return MediaQuery(
                                                                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                                                child: child!,
                                                              );
                                                            },
                                                          );
                                                          if (newStartTime != null) {
                                                            final updatedStartTime = DateTime(
                                                              startTime.year,
                                                              startTime.month,
                                                              startTime.day,
                                                              newStartTime.hour,
                                                              newStartTime.minute,
                                                            );
                                                            if (updatedStartTime.isBefore(endTime)) {
                                                              await _updateSessionTime(
                                                                log['id'],
                                                                updatedStartTime,
                                                                endTime,
                                                              );
                                                            } else {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Start time must be before end time')),
                                                              );
                                                            }
                                                          }
                                                        },
                                                        icon: Icon(Icons.access_time, size: 18),
                                                        label: Text(DateFormat('HH:mm').format(startTime), style: TextStyle(fontSize: 15)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('End Time', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                                      SizedBox(height: 4),
                                                      OutlinedButton.icon(
                                                        style: OutlinedButton.styleFrom(
                                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        onPressed: () async {
                                                          final newEndTime = await showTimePicker(
                                                            context: context,
                                                            initialTime: TimeOfDay.fromDateTime(endTime),
                                                            builder: (context, child) {
                                                              return MediaQuery(
                                                                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                                                child: child!,
                                                              );
                                                            },
                                                          );
                                                          if (newEndTime != null) {
                                                            final updatedEndTime = DateTime(
                                                              endTime.year,
                                                              endTime.month,
                                                              endTime.day,
                                                              newEndTime.hour,
                                                              newEndTime.minute,
                                                            );
                                                            if (updatedEndTime.isAfter(startTime)) {
                                                              await _updateSessionTime(
                                                                log['id'],
                                                                startTime,
                                                                updatedEndTime,
                                                              );
                                                            } else {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('End time must be after start time')),
                                                              );
                                                            }
                                                          }
                                                        },
                                                        icon: Icon(Icons.access_time, size: 18),
                                                        label: Text(DateFormat('HH:mm').format(endTime), style: TextStyle(fontSize: 15)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (!widget.selectedDate.isAfter(DateTime.now()))
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Center(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.add, color: Colors.white),
                                    label: Text('Add Session', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    onPressed: _addNewSession,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 