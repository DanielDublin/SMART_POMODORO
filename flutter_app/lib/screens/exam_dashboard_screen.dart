import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'day_summary_screen.dart';
import 'study_plans_list_screen.dart';

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
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

    // Add isActive field if it doesn't exist
    if (!plan.containsKey('isActive')) {
      await planSnap.reference.update({'isActive': true});
      plan['isActive'] = true;
    }

    final examDeadline = (plan['examDeadline'] as Timestamp).toDate();
    final sessionsPerDay = _getInt(plan['sessionsPerDay'], 1);
    final sessionLength = _getInt(plan['sessionLength'], 25);
    final pomodoroLength = _getInt(plan['pomodoroLength'], 25);
    final numberOfPomodoros = _getInt(plan['numberOfPomodoros'], 4);
    final planStart = (plan['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now().subtract(Duration(days: 30));

    // Fetch user data to get rank
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    final userRank = userSnap.data()?['rank'] ?? '1';
    final totalStudyMinutes = userSnap.data()?['totalStudyMinutes'] ?? 0;

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

    // Group logs by day
    Map<String, List<Map<String, dynamic>>> logsByDay = {};
    for (var log in logs) {
      if (log['sessionType'] != null && log['sessionType'] != 'study') continue;
      final d = (log['startTime'] as Timestamp).toDate();
      final key = DateFormat('yyyy-MM-dd').format(d);
      logsByDay.putIfAbsent(key, () => []).add(log);
    }

    // --- Weekly stats ---
    final weekLogs = List<Map<String, dynamic>>.from(logs).where((l) {
      final d = (l['startTime'] as Timestamp).toDate();
      return DateTime.now().difference(d).inDays < 7;
    }).toList();
    final weekSessions = weekLogs.length;
    final weekMinutes = weekLogs.fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0));

    // Get study days (dates user planned to study)
    final selectedDays = (plan['selectedDays'] as List?)?.map((ts) => (ts as Timestamp).toDate()).toSet() ?? {};
    Set<String> studyDayKeys = selectedDays.map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();

    // --- Consistency streak ---
    int streak = 0;
    DateTime streakDay = DateTime.now().subtract(Duration(days: 1)); // Start from yesterday
    int maxDaysToCheck = 365; // Prevent infinite loop
    int daysChecked = 0;
    
    while (daysChecked < maxDaysToCheck) {
      final key = DateFormat('yyyy-MM-dd').format(streakDay);
      final hasSessionLogs = logsByDay[key]?.isNotEmpty ?? false;
      final isStudyDay = studyDayKeys.contains(key);
      
      if (hasSessionLogs) {
        // User studied this day (planned or unplanned) - count it
        streak++;
        streakDay = streakDay.subtract(Duration(days: 1));
      } else if (isStudyDay) {
        // User missed a planned study day - streak ends
        break;
      } else {
        // Not a study day and no logs - skip this day, continue checking
        streakDay = streakDay.subtract(Duration(days: 1));
      }
      daysChecked++;
    }

    return {
      'plan': plan,
      'logs': logs,
      'examDeadline': examDeadline,
      'sessionsPerDay': sessionsPerDay,
      'sessionLength': sessionLength,
      'pomodoroLength': pomodoroLength,
      'numberOfPomodoros': numberOfPomodoros,
      'planStart': planStart,
      'userRank': userRank,
      'totalStudyMinutes': totalStudyMinutes,
      'streak': streak,
    };
  }

  String _getRankTitle(String rank) {
    switch (rank) {
      case "10": return "Pomodoro Pro";
      case "9": return "Study Sage";
      case "8": return "Mind Master";
      case "7": return "Focus Ninja";
      case "6": return "Strategist";
      case "5": return "Researcher";
      case "4": return "Scholar";
      case "3": return "Apprentice";
      case "2": return "Sprout";
      default: return "Seedling";
    }
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
          final numberOfPomodoros = snapshot.data!['numberOfPomodoros'];
          final planStart = snapshot.data!['planStart'];
          final userRank = snapshot.data!['userRank'];
          final totalStudyMinutes = snapshot.data!['totalStudyMinutes'];
          final streak = snapshot.data!['streak'];

          final selectedDays = (plan['selectedDays'] as List?)?.map((ts) => (ts as Timestamp).toDate()).toSet() ?? {};
          Set<String> studyDayKeys = selectedDays.map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();

          // Group logs by day (handle empty logs case)
          Map<String, List<Map<String, dynamic>>> logsByDay = {};
          for (var log in logs) {
            if (log['sessionType'] != null && log['sessionType'] != 'study') continue;
            final d = (log['startTime'] as Timestamp).toDate();
            final key = DateFormat('yyyy-MM-dd').format(d);
            logsByDay.putIfAbsent(key, () => []).add(log);
          }

          // --- Weekly stats ---
          final weekLogs = List<Map<String, dynamic>>.from(logs).where((l) {
            final d = (l['startTime'] as Timestamp).toDate();
            return DateTime.now().difference(d).inDays < 7;
          }).toList();
          final weekSessions = weekLogs.length;
          final weekMinutes = weekLogs.fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0));

          // --- Calculations ---
          final now = DateTime.now();
          final planStartDate = DateTime(planStart.year, planStart.month, planStart.day);
          final examDeadlineDate = DateTime(examDeadline.year, examDeadline.month, examDeadline.day);
          final todayDate = DateTime(now.year, now.month, now.day);

          // Calculate expectedDay and number of selectedDays
          final expectedDay = pomodoroLength * numberOfPomodoros * sessionsPerDay;
          final selectedDaysList = selectedDays.toList();
          final totalSelectedDays = selectedDaysList.length;
          final totalExpectedMinutes = expectedDay * totalSelectedDays;
          final totalActualMinutes = logs.fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0));
          // Cap readiness score at 100%
          final rawReadinessScore = totalExpectedMinutes == 0 ? 0 : (totalActualMinutes / totalExpectedMinutes * 100);
          final readinessScore = rawReadinessScore.clamp(0, 100);

          // For current expected (to determine status): only consider selectedDays whose date is strictly less than today
          final pastSelectedDays = selectedDaysList.where((d) => d.isBefore(todayDate)).length;
          final currentExpectedMinutes = expectedDay * pastSelectedDays;
          final currentReadinessScore = currentExpectedMinutes == 0
              ? (totalActualMinutes > 0 ? 100 : 0)
              : (totalActualMinutes / currentExpectedMinutes * 100);

          String status;
          IconData statusIcon;
          Color statusColor;
          
          // Only show completed if raw score is >= 100
          if (rawReadinessScore >= 100) {
            status = 'Completed';
            statusIcon = Icons.emoji_events;
            statusColor = Colors.amber[700]!;
          } else if (currentReadinessScore > 105) {
            status = 'Ahead';
            statusIcon = Icons.trending_up;
            statusColor = Colors.green;
          } else if (currentReadinessScore >= 95) {
            status = 'On Track';
            statusIcon = Icons.check_circle;
            statusColor = Colors.blue;
          } else {
            status = 'Behind';
            statusIcon = Icons.warning;
            statusColor = Colors.red;
          }

          // --- Heatmap data ---
          Map<String, int> heatmap = {};
          for (var l in logs) {
            final d = (l['startTime'] as Timestamp).toDate();
            final key = DateFormat('yyyy-MM-dd').format(d);
            heatmap[key] = (heatmap[key] ?? 0) + 1;
          }
          final firstDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
          final lastDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
          int daysInMonth = lastDayOfMonth.day;
          DateTime today = DateTime.now();

          List<TableRow> calendarRows = [];
          // Header
          calendarRows.add(TableRow(
            children: List.generate(7, (i) {
              final weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][i];
              return Center(child: Text(weekday, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));
            }),
          ));
          int dayOffset = firstDayOfMonth.weekday % 7;
          int dayNum = 1;
          for (int w = 0; w < 6; w++) {
            List<Widget> cells = [];
            for (int d = 0; d < 7; d++) {
              if (w == 0 && d < dayOffset) {
                cells.add(Container());
              } else if (dayNum <= daysInMonth) {
                final date = DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
                final key = DateFormat('yyyy-MM-dd').format(date);
                final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
                final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
                final isStudyDay = studyDayKeys.contains(key);
                double progress = 0;
                if (logsByDay.containsKey(key)) {
                  final logsForDay = logsByDay[key]!;
                  final totalDuration = logsForDay.fold<num>(0, (sum, l) => sum + (l['duration'] ?? 0));
                  final totalDurationInt = totalDuration.toInt();
                  progress = expectedDay > 0 ? (totalDurationInt / expectedDay) : 0;
                }
                final hasUnplannedStudy = !isStudyDay && logsByDay.containsKey(key);
                int unplannedMinutes = 0;
                if (hasUnplannedStudy) {
                  final logsForDay = logsByDay[key]!;
                  unplannedMinutes = logsForDay.fold<num>(0, (sum, l) => sum + (l['duration'] ?? 0)).toInt();
                }
                Color bgColor = Colors.grey[200]!;
                String progressText = '';
                if (isStudyDay) {
                  if (isPast) {
                    if (progress >= 1.0) {
                      bgColor = Colors.green[400]!;
                      progressText = '100%';
                    } else if (progress > 0) {
                      bgColor = Colors.amber[400]!;
                      progressText = '${(progress * 100).toInt()}%';
                    } else {
                      bgColor = Colors.red[300]!;
                      progressText = '0%';
                    }
                  } else if (isFuture) {
                    bgColor = Colors.grey[400]!; // darker gray for future study days
                  } else if (isToday) {
                    bgColor = Colors.red[100]!;
                  }
                } else if (hasUnplannedStudy) {
                  bgColor = Colors.blue[400]!;
                } else {
                  bgColor = Colors.grey[200]!;
                }
                cells.add(GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DaySummaryScreen(
                          uid: widget.uid,
                          planId: widget.planId,
                          selectedDate: date,
                          expectedSessions: sessionsPerDay,
                          pomodoroLength: pomodoroLength,
                          numberOfPomodoros: numberOfPomodoros,
                        ),
                      ),
                    ).then((hasChanges) async {
                      if (hasChanges == true) {
                        setState(() {
                          _dashboardData = fetchDashboardData();
                        });
                        // Refresh study plans and rank on home screen
                        final homeState = context.findAncestorStateOfType<StudyPlansListScreenState>();
                        if (homeState != null) {
                          await homeState.fetchStudyPlans();
                          homeState.refreshRank();
                          await homeState.checkRankOnStartup();
                        }
                      }
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday ? Border.all(color: Colors.red, width: 2) : null,
                    ),
                    height: 56,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$dayNum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        if (isStudyDay && isPast)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('($progressText)', style: TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                        if (hasUnplannedStudy)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$unplannedMinutes min',
                              style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ));
                dayNum++;
              } else {
                cells.add(Container());
              }
            }
            calendarRows.add(TableRow(children: cells));
            if (dayNum > daysInMonth) break;
          }

          // Legend
          Widget legend = Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: [
                _legendDotWithLabel(Colors.green[400]!, 'Completed'),
                _legendDotWithLabel(Colors.amber[400]!, 'Partial'),
                _legendDotWithLabel(Colors.red[300]!, 'Missed'),
                _legendDotWithLabel(Colors.blue[400]!, 'Unplanned Study Day'),
                _legendDotWithLabel(Colors.grey[400]!, 'Future Study Day'),
                _legendDotWithLabel(Colors.grey[200]!, 'Idle Day'),
              ],
            ),
          );

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
                        child: Icon(Icons.school, size: 40, color: Colors.red),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          plan['sessionName'] ?? 'Unnamed Plan',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[100]!, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/mascots/rank${userRank}.png',
                              height: 24,
                              width: 24,
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'RANK ${userRank}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _getRankTitle(userRank),
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                              Text('${totalSelectedDays - pastSelectedDays} Days Left', style: TextStyle(fontSize: 12)),
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
                              Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                // Custom Calendar
                Card(
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                                });
                              },
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_calendarMonth),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                                });
                              },
                            ),
                          ],
                        ),
                        Table(children: calendarRows),
                        legend,
                      ],
                    ),
                  ),
                ),
                // Minutes Studied Bar Chart (Past Week)
                Builder(
                  builder: (context) {
                    // --- Minutes Studied Bar Chart Data (Mon-Sun, past week) ---
                    final nowDate = DateTime.now();
                    final weekStart = nowDate.subtract(Duration(days: nowDate.weekday - 1)); // Monday
                    final weekDates = List.generate(7, (i) => weekStart.add(Duration(days: i)));
                    List<List<Map<String, dynamic>>> weekLogsByDay = List.generate(7, (i) => []);
                    for (var l in logs) {
                      final d = (l['startTime'] as Timestamp).toDate();
                      for (int i = 0; i < 7; i++) {
                        if (d.year == weekDates[i].year && d.month == weekDates[i].month && d.day == weekDates[i].day) {
                          weekLogsByDay[i].add(l);
                        }
                      }
                    }
                    // --- Missed Sessions (planned study days in past week with 0 logs) ---
                    List<DateTime> missedSessions = [];
                    int studiedPlannedDays = 0;
                    for (int i = 0; i < 7; i++) {
                      final date = weekDates[i];
                      final key = DateFormat('yyyy-MM-dd').format(date);
                      final isPast = date.isBefore(DateTime(nowDate.year, nowDate.month, nowDate.day + 1));
                      if (isPast && studyDayKeys.contains(key)) {
                        if (weekLogsByDay[i].isEmpty) {
                          missedSessions.add(date);
                        } else {
                          studiedPlannedDays++;
                        }
                      }
                    }
                    final barValues = [
                      for (int i = 0; i < 7; i++)
                        weekLogsByDay[i].fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0))
                    ];
                    final maxBar = barValues.isNotEmpty ? barValues.reduce((a, b) => a > b ? a : b) : 0;
                    int touchedIndex = -1;
                    return StatefulBuilder(
                      builder: (context, setBarState) {
                        return Column(
                          children: [
                            // Minutes Studied Bar Chart (Past Week)
                            Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Minutes Studied (Past Week)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                    SizedBox(height: 16),
                                    SizedBox(
                                      height: 220,
                                      child: BarChart(
                                        BarChartData(
                                          alignment: BarChartAlignment.spaceAround,
                                          maxY: (maxBar + 30).toDouble(),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              tooltipBgColor: Colors.red[100],
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                return BarTooltipItem(
                                                  '${barValues[group.x]} min',
                                                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                                );
                                              },
                                            ),
                                            touchCallback: (event, response) {
                                              if (response != null && response.spot != null && event.isInterestedForInteractions) {
                                                setBarState(() {
                                                  touchedIndex = response.spot!.touchedBarGroupIndex;
                                                });
                                              } else {
                                                setBarState(() {
                                                  touchedIndex = -1;
                                                });
                                              }
                                            },
                                          ),
                                          titlesData: FlTitlesData(
                                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                getTitlesWidget: (double value, TitleMeta meta) {
                                                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                                  return Padding(
                                                    padding: EdgeInsets.only(top: 8),
                                                    child: Text(
                                                      days[value.toInt()],
                                                      style: TextStyle(fontWeight: FontWeight.w500),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          gridData: FlGridData(show: false),
                                          barGroups: [
                                            for (int i = 0; i < 7; i++)
                                              BarChartGroupData(
                                                x: i,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: barValues[i].toDouble(),
                                                    color: Colors.red,
                                                    width: 22,
                                                    borderRadius: BorderRadius.circular(6),
                                                    borderSide: touchedIndex == i ? BorderSide(color: Colors.black, width: 2) : BorderSide.none,
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (touchedIndex != -1)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Center(
                                          child: Text(
                                            '${barValues[touchedIndex]} minutes studied',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    SizedBox(height: 12),
                                    Center(child: Text('Total minutes studied each day', style: TextStyle(color: Colors.black54))),
                                  ],
                                ),
                              ),
                            ),
                            // Missed Sessions Card
                            Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Missed Sessions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    for (final missed in missedSessions)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning, color: Colors.red, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              DateFormat('yyyy-MM-dd').format(missed),
                                              style: TextStyle(fontWeight: FontWeight.bold)
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (missedSessions.isEmpty)
                                      Text(
                                        'No missed sessions this week',
                                        style: TextStyle(color: Colors.black54)
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
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

// --- Legend Dot Widget ---
Widget _legendDot(Color color, String label) {
  return Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ),
  );
}

// Add this helper below _legendDot:
Widget _legendDotWithLabel(Color color, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13)),
    ],
  );
} 