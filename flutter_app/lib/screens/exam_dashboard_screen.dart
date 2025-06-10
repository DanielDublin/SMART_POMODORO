import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'view_sessions_screen.dart';

class ExamDashboardScreen extends StatefulWidget {
  final String planId;
  final String uid;
  const ExamDashboardScreen({required this.planId, required this.uid, Key? key})
      : assert(planId != null && planId != ''),
        assert(uid != null && uid != ''),
        super(key: key);

  @override
  State<ExamDashboardScreen> createState() => _ExamDashboardScreenState();
}

class _ExamDashboardScreenState extends State<ExamDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = fetchDashboardData();
  }

  int _getInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<Map<String, dynamic>> fetchDashboardData() async {
    if (widget.uid.isEmpty || widget.planId.isEmpty) {
      throw Exception('Error: Missing user or plan ID');
    }
    // Fetch study plan
    final planSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('sessions')
        .doc(widget.planId)
        .get();
    if (!planSnap.exists) {
      throw Exception('Study plan not found for this user.');
    }
    final plan = planSnap.data()!;
    print('Plan data: $plan');
    final examDeadline = (plan['examDeadline'] as Timestamp).toDate();
    final sessionsPerDay = _getInt(plan['sessionsPerDay'], 1);
    final sessionLength = _getInt(plan['sessionLength'], 25);
    final pomodoroLength = _getInt(plan['pomodoroLength'], 25);
    final longBreakAfter = _getInt(plan['longBreakAfter'], 4);
    final planStart = (plan['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now().subtract(Duration(days: 30));

    // Fetch session logs for this plan and user
    print('Fetching session logs for user: ${widget.uid}, plan: ${widget.planId}');
    final logsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('session_logs')
        .where('sessionPlanId', isEqualTo: widget.planId)
        .where('sessionType', isEqualTo: 'study')
        .get();
    print('Fetched ${logsSnap.docs.length} logs');
    final logs = List<Map<String, dynamic>>.from(logsSnap.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
    print('Logs: $logs');

    return {
      'plan': plan,
      'logs': logs,
      'examDeadline': examDeadline,
      'sessionsPerDay': sessionsPerDay,
      'sessionLength': sessionLength,
      'pomodoroLength': pomodoroLength,
      'longBreakAfter': longBreakAfter,
      'planStart': planStart,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Statistics', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: \n${snapshot.error}'));
          }
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final plan = snapshot.data!['plan'];
          final logs = List<Map<String, dynamic>>.from(snapshot.data!['logs']);
          final examDeadline = snapshot.data!['examDeadline'];
          final sessionsPerDay = snapshot.data!['sessionsPerDay'];
          final sessionLength = snapshot.data!['sessionLength'];
          final pomodoroLength = snapshot.data!['pomodoroLength'];
          final longBreakAfter = snapshot.data!['longBreakAfter'];
          final planStart = snapshot.data!['planStart'];

          if (logs.isEmpty) {
            return Center(
              child: Card(
                margin: EdgeInsets.all(32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.blueGrey),
                      SizedBox(height: 16),
                      Text(
                        'No study sessions have been reported for this plan yet.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start your first Pomodoro to see your statistics here!',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // --- Calculations ---
          final now = DateTime.now();
          final planStartDate = DateTime(planStart.year, planStart.month, planStart.day);
          final examDeadlineDate = DateTime(examDeadline.year, examDeadline.month, examDeadline.day);
          final todayDate = DateTime(now.year, now.month, now.day);
          final lastDay = todayDate.isBefore(examDeadlineDate) ? todayDate : examDeadlineDate;
          final plannedStudyDaysUpToToday = lastDay.difference(planStartDate).inDays + 1;
          final totalDays = examDeadlineDate.difference(planStartDate).inDays + 1;
          final daysLeft = max(0, examDeadlineDate.difference(todayDate).inDays);
          final dailyStudyLength = pomodoroLength * longBreakAfter * sessionsPerDay;
          final totalSessions = totalDays * sessionsPerDay;
          final expectedSessionsByNow = plannedStudyDaysUpToToday * sessionsPerDay;
          final actualSessions = logs.length;
          final totalActualMinutes = logs.fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0));
          final totalExpectedMinutes = dailyStudyLength * plannedStudyDaysUpToToday;
          final readinessScore = totalExpectedMinutes == 0 ? 0 : (totalActualMinutes / totalExpectedMinutes * 100).clamp(0, 200);
          String status;
          IconData statusIcon;
          Color statusColor;
          if (readinessScore > 105) {
            status = 'Ahead';
            statusIcon = Icons.trending_up;
            statusColor = Colors.green;
          } else if (readinessScore >= 95) {
            status = 'On Track';
            statusIcon = Icons.check_circle;
            statusColor = Colors.blue;
          } else {
            status = 'Behind';
            statusIcon = Icons.warning;
            statusColor = Colors.red;
          }

          // --- Burn-down chart data ---
          List<FlSpot> idealLine = [];
          List<FlSpot> actualLine = [];
          int sessionsRemaining = totalSessions is int ? totalSessions : totalSessions.toInt();
          Map<String, int> sessionsPerDayMap = {};
          for (var l in logs) {
            final d = (l['startTime'] as Timestamp).toDate();
            final key = DateFormat('yyyy-MM-dd').format(d);
            sessionsPerDayMap[key] = (sessionsPerDayMap[key] ?? 0) + 1;
          }
          for (int i = 0; i <= totalDays; i++) {
            idealLine.add(FlSpot(i.toDouble(), (totalSessions - i * sessionsPerDay).toDouble().clamp(0, totalSessions.toDouble())));
            // Actual: subtract sessions completed up to this day
            final day = planStart.add(Duration(days: i));
            final key = DateFormat('yyyy-MM-dd').format(day);
            if (sessionsPerDayMap.containsKey(key)) {
              sessionsRemaining -= sessionsPerDayMap[key]!;
            }
            actualLine.add(FlSpot(i.toDouble(), (sessionsRemaining.toDouble().clamp(0, totalSessions.toDouble())).toDouble()));
          }

          // --- Heatmap data ---
          Map<String, int> heatmap = {};
          for (var l in logs) {
            final d = (l['startTime'] as Timestamp).toDate();
            final key = DateFormat('yyyy-MM-dd').format(d);
            heatmap[key] = (heatmap[key] ?? 0) + 1;
          }
          final firstDayOfMonth = DateTime(now.year, now.month, 1);
          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

          // --- Consistency streak ---
          int streak = 0;
          DateTime streakDay = now;
          while (true) {
            final key = DateFormat('yyyy-MM-dd').format(streakDay);
            if ((heatmap[key] ?? 0) > 0) {
              streak++;
              streakDay = streakDay.subtract(Duration(days: 1));
            } else {
              break;
            }
          }

          // --- Weekly stats ---
          final weekLogs = List<Map<String, dynamic>>.from(logs).where((l) {
            final d = (l['startTime'] as Timestamp).toDate();
            return now.difference(d).inDays < 7;
          }).toList();

          final weekSessions = weekLogs.length;
          final weekMinutes = weekLogs.fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0));

          return SingleChildScrollView(
            child: Column(
              children: [
                // Mascot & Title
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.school, size: 40, color: Colors.red), // Placeholder mascot
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'DASHBOARD',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      // Rank (optional)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('RANK: Owl', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                // Main Card
                Card(
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircularPercentIndicator(
                          radius: 60,
                          lineWidth: 12,
                          percent: (readinessScore / 100).clamp(0, 1),
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${readinessScore.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                              Text('$daysLeft Days Left', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          progressColor: Colors.red,
                          backgroundColor: Colors.grey[200]!,
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                        SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('On Track', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(statusIcon, color: statusColor),
                                  SizedBox(width: 6),
                                  Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Session Burn-down Chart
                Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Session Burn-down Chart', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: idealLine,
                                  isCurved: false,
                                  color: Colors.red[200],
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(show: false),
                                  dashArray: [8, 4],
                                ),
                                LineChartBarData(
                                  spots: actualLine,
                                  isCurved: false,
                                  color: Colors.red[800],
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.linear_scale, color: Colors.red[200], size: 18),
                            Text(' Ideal Pace   ', style: TextStyle(color: Colors.red[200])),
                            Icon(Icons.linear_scale, color: Colors.red[800], size: 18),
                            Text(' Actual Pace', style: TextStyle(color: Colors.red[800])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Weekly Heatmap
                Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Weekly Performance', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text('$weekSessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                Text('Total\nSessions', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('$weekMinutes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                Text('Total\nHours', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // Heatmap calendar
                        _HeatmapCalendar(
                          heatmap: heatmap,
                          firstDay: firstDayOfMonth,
                          lastDay: lastDayOfMonth,
                        ),
                      ],
                    ),
                  ),
                ),
                // Key Stats Row
                Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text('$actualSessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            Text('Total Sessions', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('${(totalActualMinutes / 60).toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            Text('Total Hours', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                Text('$streak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                SizedBox(width: 4),
                                Text('🔥', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                            Text('Consistency Streak', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Motivational Message & Actions
                Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          status == 'Behind'
                              ? "Let's catch up!"
                              : 'Consistency is 🔥!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: status == 'Behind' ? Colors.red : Colors.orange,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.file_download, color: Colors.white),
                              label: Text('Export Data', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViewSessionsScreen(
                                      uid: widget.uid,
                                      planId: widget.planId,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.list_alt, color: Colors.white),
                              label: Text('View Sessions', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.emoji_events, color: Colors.white),
                              label: Text('View Rewards', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Heatmap Calendar Widget ---
class _HeatmapCalendar extends StatelessWidget {
  final Map<String, int> heatmap;
  final DateTime firstDay;
  final DateTime lastDay;
  const _HeatmapCalendar({required this.heatmap, required this.firstDay, required this.lastDay});

  Color _colorForCount(int count) {
    if (count == 0) return Colors.grey[200]!;
    if (count == 1) return Colors.red[100]!;
    if (count == 2) return Colors.red[300]!;
    if (count == 3) return Colors.red[500]!;
    return Colors.red[800]!;
  }

  @override
  Widget build(BuildContext context) {
    final days = lastDay.difference(firstDay).inDays + 1;
    final weeks = ((days + firstDay.weekday - 1) / 7).ceil();
    List<TableRow> rows = [];
    // Header
    rows.add(TableRow(
      children: List.generate(7, (i) {
        final weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i];
        return Center(child: Text(weekday, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
      }),
    ));
    // Calendar
    int dayOffset = firstDay.weekday - 1;
    int dayNum = 0;
    for (int w = 0; w < weeks; w++) {
      List<Widget> cells = [];
      for (int d = 0; d < 7; d++) {
        if (w == 0 && d < dayOffset) {
          cells.add(Container());
        } else if (dayNum < days) {
          final date = firstDay.add(Duration(days: dayNum));
          final key = DateFormat('yyyy-MM-dd').format(date);
          final count = heatmap[key] ?? 0;
          cells.add(Container(
            margin: EdgeInsets.all(2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _colorForCount(count),
              borderRadius: BorderRadius.circular(4),
            ),
          ));
          dayNum++;
        } else {
          cells.add(Container());
        }
      }
      rows.add(TableRow(children: cells));
    }
    return Table(children: rows);
  }
} 