import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'study_plans_list_screen.dart';

class SummaryScreen extends StatefulWidget {
  @override
  _SummaryScreenState createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<Map<String, dynamic>> _summaryData;

  @override
  void initState() {
    super.initState();
    _summaryData = _fetchSummaryData();
  }

  Future<Map<String, dynamic>> _fetchSummaryData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    print('Fetching summary data for user: ${user.uid}');

    // Get all active plans
    final QuerySnapshot<Map<String, dynamic>> activePlans = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .get();

    print('Found ${activePlans.docs.length} active study plans');

    // If no plans have isActive field, check if there are any plans at all
    if (activePlans.docs.isEmpty) {
      final allPlansSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .get();
      
      // If there are no plans at all, return empty data
      if (allPlansSnap.docs.isEmpty) {
        print('No study plans found for user');
        return {
          'planCount': 0,
          'totalCompletedSessions': 0,
          'totalPlannedSessions': 0,
          'planSummaries': [],
          'userRank': '1',
          'totalStudyMinutes': 0,
          'hasNoPlans': true, // Flag to indicate no plans exist
        };
      }
      
      // Update all existing plans to be active
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in allPlansSnap.docs) {
        batch.update(doc.reference, {'isActive': true});
      }
      await batch.commit();

      // Refetch the plans
      return _fetchSummaryData();
    }

    List<Map<String, dynamic>> planSummaries = [];
    int totalCompletedSessions = 0;
    int totalPlannedSessions = 0;
    int totalStudyMinutes = 0;

    // Process each plan
    for (QueryDocumentSnapshot<Map<String, dynamic>> doc in activePlans.docs) {
      final data = doc.data();
      final planName = data['sessionName']?.toString() ?? data['name']?.toString() ?? 'Unnamed Plan';
      
      print('Processing plan: $planName (${doc.id})');
      
      // Get plan parameters
      final selectedDays = (data['selectedDays'] as List?)?.map((ts) => (ts as Timestamp).toDate()).toList() ?? [];
      final pomodoroLength = (data['pomodoroLength'] as num?)?.toInt() ?? 25;
      final sessionsPerDay = (data['sessionsPerDay'] as num?)?.toInt() ?? 1;
      final numberOfPomodoros = (data['numberOfPomodoros'] as num?)?.toInt() ?? 4;

      print('Plan details:');
      print('- Selected days: ${selectedDays.length}');
      print('- Sessions per day: $sessionsPerDay');
      print('- Pomodoro length: $pomodoroLength');
      print('- Number of pomodoros: $numberOfPomodoros');
      print('- Number of pomodoros: $numberOfPomodoros');

      // Calculate total planned sessions for this plan
      final totalPlanSessions = selectedDays.length * sessionsPerDay;
      print('- Total planned sessions for this plan: $totalPlanSessions');

      // Fetch session logs for this plan
      final QuerySnapshot<Map<String, dynamic>> logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('session_logs')
          .where('sessionPlanId', isEqualTo: doc.id)
          .where('sessionType', isEqualTo: 'study')
          .get();

      print('Found ${logsSnap.docs.length} study session logs for this plan');

      // Calculate completed sessions
      final totalDuration = logsSnap.docs.fold<int>(
        0,
        (sum, doc) {
          final duration = (doc.data()['duration'] as num?)?.toInt() ?? 0;
          print('Session duration: $duration minutes');
          return sum + duration;
        },
      );
      
      totalStudyMinutes += totalDuration;
      
      print('Total duration for this plan: $totalDuration minutes');
      final completedSessions = (totalDuration / (pomodoroLength * numberOfPomodoros)).floor();
      print('Completed sessions for this plan: $completedSessions');

      // Update totals
      totalCompletedSessions += completedSessions;
      totalPlannedSessions += totalPlanSessions;

      print('Running totals:');
      print('- Total completed sessions so far: $totalCompletedSessions');
      print('- Total planned sessions so far: $totalPlannedSessions');

      // Calculate progress percentage
      final progress = totalPlanSessions > 0 
          ? (completedSessions / totalPlanSessions * 100).clamp(0, 100).round()
          : 0;

      // Get last active time
      DateTime? lastActiveTime;
      if (logsSnap.docs.isNotEmpty) {
        lastActiveTime = logsSnap.docs
            .map((doc) => (doc.data()['startTime'] as Timestamp).toDate())
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      final lastActive = lastActiveTime != null 
          ? DateFormat('yyyy-MM-dd').format(lastActiveTime)
          : 'No activity';

      planSummaries.add({
        'name': planName,
        'completedSessions': completedSessions,
        'totalSessions': totalPlanSessions,
        'progress': progress,
        'lastActive': lastActive,
      });
    }

    // Update user's rank in Firestore based on total study minutes
    final userRank = _calculateRank(totalStudyMinutes);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'rank': userRank,
          'totalStudyMinutes': totalStudyMinutes,
        }, SetOptions(merge: true));

    print('Final totals:');
    print('Total completed sessions: $totalCompletedSessions');
    print('Total planned sessions: $totalPlannedSessions');
    print('Total study minutes: $totalStudyMinutes');
    print('User rank: $userRank');
    print('Plan summaries: $planSummaries');

    return {
      'planCount': activePlans.docs.length,
      'totalCompletedSessions': totalCompletedSessions,
      'totalPlannedSessions': totalPlannedSessions,
      'planSummaries': planSummaries,
      'userRank': userRank,
      'totalStudyMinutes': totalStudyMinutes,
    };
  }

  String _calculateRank(int totalMinutes) {
    final ranks = [
      {'minutes': 0},      // Rank 1 - Seedling
      {'minutes': 100},    // Rank 2 - Sprout
      {'minutes': 300},    // Rank 3 - Apprentice
      {'minutes': 700},    // Rank 4 - Scholar
      {'minutes': 1500},   // Rank 5 - Researcher
      {'minutes': 3000},   // Rank 6 - Strategist
      {'minutes': 5000},   // Rank 7 - Focus Ninja
      {'minutes': 8000},   // Rank 8 - Mind Master
      {'minutes': 12000},  // Rank 9 - Study Sage
      {'minutes': 20000},  // Rank 10 - Pomodoro Pro
    ];

    int rankIndex = 0;
    for (int i = 0; i < ranks.length; i++) {
      if (totalMinutes >= ranks[i]['minutes']!) {
        rankIndex = i;
      } else {
        break;
      }
    }
    return (rankIndex + 1).toString();
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
        backgroundColor: Colors.red,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => StudyPlansListScreen()),
            );
          },
        ),
        title: Text(
          'Overall Plans Summary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final planSummaries = List<Map<String, dynamic>>.from(data['planSummaries']);
          final hasNoPlans = data['hasNoPlans'] ?? false;

          // If user has no study plans at all, show a message
          if (hasNoPlans) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 80, color: Colors.grey[300]),
                  SizedBox(height: 24),
                  Text(
                    'No study plans available.',
                    style: TextStyle(fontSize: 18, color: Colors.blueGrey[700]),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Your Study Journey Section
                Card(
                  margin: EdgeInsets.all(16),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Your Study Journey',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'You are currently managing ${data['planCount']} study plans.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Total Sessions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${data['totalCompletedSessions']} / ${data['totalPlannedSessions']}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Overall Progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    data['totalPlannedSessions'] > 0
                                        ? '${(data['totalCompletedSessions'] * 100 / data['totalPlannedSessions']).clamp(0, 100).round()}%'
                                        : '0%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        LinearPercentIndicator(
                          padding: EdgeInsets.zero,
                          lineHeight: 8.0,
                          percent: data['totalPlannedSessions'] > 0
                              ? (data['totalCompletedSessions'] / data['totalPlannedSessions']).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: Colors.grey[200],
                          progressColor: Colors.red,
                          barRadius: Radius.circular(4),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Keep up the great work across all your plans!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                // Individual Plan Overview Section
                Container(
                  width: double.infinity,
                  child: Card(
                    margin: EdgeInsets.all(16),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Individual Plan Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 20),
                          if (planSummaries.isEmpty)
                            Center(
                              child: Text(
                                'No active study plans',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ...planSummaries.map((plan) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      plan['name'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Last Active: ${plan['lastActive']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              LinearPercentIndicator(
                                padding: EdgeInsets.zero,
                                lineHeight: 6.0,
                                percent: (plan['progress'] / 100).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey[200],
                                progressColor: Colors.red,
                                barRadius: Radius.circular(3),
                                width: MediaQuery.of(context).size.width - 64, // Full width minus padding
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${plan['completedSessions']} / ${plan['totalSessions']} sessions completed (${plan['progress']}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              if (planSummaries.last != plan) // Don't add divider after last item
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(height: 1, color: Colors.grey[200]),
                                ),
                              if (planSummaries.last == plan)
                                SizedBox(height: 8),
                            ],
                          )).toList(),
                        ],
                      ),
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