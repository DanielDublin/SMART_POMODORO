import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_scaffold.dart';
import '../services/firestore_service.dart';
import '../services/mock_data_service.dart';
import '../services/notification_service.dart';
import 'study_planner_settings_screen.dart';
import 'exam_dashboard_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortOption {
  deadline,
  name
}

class StudyPlansListScreen extends StatefulWidget {
  @override
  StudyPlansListScreenState createState() => StudyPlansListScreenState();
}

class StudyPlansListScreenState extends State<StudyPlansListScreen> {
  List<Map<String, dynamic>> studyPlans = [];
  bool isLoading = true;
  String? error;
  bool isConfirmingDelete = false;
  bool isConfirmingEdit = false;
  bool isGeneratingMockData = false;
  String currentSortBy = 'deadline';
  bool isAscending = true;
  late Future<String> rankFuture;

  // Popup control
  static bool _motivationPopupShown = false;

  void sortStudyPlans(SortOption option) {
    setState(() {
      if (currentSortBy == option.toString().split('.').last) {
        isAscending = !isAscending;
      } else {
        isAscending = true;
      }
      
      switch (option) {
        case SortOption.deadline:
          currentSortBy = 'deadline';
          break;
        case SortOption.name:
          currentSortBy = 'name';
          break;
      }
    });
    
    // Fetch data with new sorting
    fetchStudyPlans();
  }

  @override
  void initState() {
    super.initState();
    fetchStudyPlans();
    rankFuture = _calculateUserRank();
    checkRankOnStartup();
    // Add a delay to ensure everything is loaded before checking notifications
    Future.delayed(Duration(seconds: 2), () {
      checkDailyReminders();
    });
  }

  Future<void> fetchStudyPlans() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final sessions = await FirestoreService.getStudySessions(
        sortBy: currentSortBy,
        ascending: isAscending,
      );
      setState(() {
        studyPlans = sessions;
        isLoading = false;
      });
      // After plans are loaded, check and show motivational popup
      _checkAndShowMotivationPopupAfterAllLoaded();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> generateMockData() async {
    setState(() {
      isGeneratingMockData = true;
    });

    try {
      await MockDataService().generateMockLogsForCurrentUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mock data generation completed'),
          backgroundColor: Colors.green,
        ),
      );
      await fetchStudyPlans();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating mock data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isGeneratingMockData = false;
      });
    }
  }

  Future<void> deleteStudyPlan(String planId) async {
    try {
      // Delete all session_logs with sessionPlanId == planId
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final logsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('session_logs')
            .where('sessionPlanId', isEqualTo: planId)
            .get();
        for (final doc in logsSnap.docs) {
          await doc.reference.delete();
        }
      }
      await FirestoreService.deleteStudySession(planId);
      await fetchStudyPlans(); // Refresh the list
      refreshRank(); // Recalculate user rank
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Study plan deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete study plan: $e')),
      );
    }
  }

  String formatDeadline(dynamic deadline) {
    if (deadline == null) return 'No deadline set';
    try {
      if (deadline is Timestamp) {
        return DateFormat('dd/MM/yy').format(deadline.toDate());
      }
      return 'Invalid date';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void navigateToAddPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyPlannerSettingsScreen()),
    );
    await fetchStudyPlans();
  }

  Future<String> _calculateUserRank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "1";

    // Calculate total minutes from all session logs
    final logsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('session_logs')
        .where('sessionType', isEqualTo: 'study')
        .get();

    final logs = logsSnap.docs.map((doc) => doc.data()).toList();
    final totalMinutes = logs.fold<int>(0, (sum, log) => 
      sum + (log['duration'] is int ? log['duration'] as int : 
            (log['duration'] is double ? (log['duration'] as double).toInt() : 0)));

    final ranks = [
      {'minutes': 0},      // Rank 1
      {'minutes': 100},    // Rank 2
      {'minutes': 300},    // Rank 3
      {'minutes': 700},    // Rank 4
      {'minutes': 1500},   // Rank 5
      {'minutes': 3000},   // Rank 6
      {'minutes': 5000},   // Rank 7
      {'minutes': 8000},   // Rank 8
      {'minutes': 12000},  // Rank 9
      {'minutes': 20000},  // Rank 10
    ];

    int rankIndex = 0;
    for (int i = 0; i < ranks.length; i++) {
      if (totalMinutes >= ranks[i]['minutes']!) {
        rankIndex = i;
      } else {
        break;
      }
    }
    final userRank = (rankIndex + 1).toString();

    // Update user document with new rank and total minutes
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'rank': userRank,
          'totalStudyMinutes': totalMinutes,
        }, SetOptions(merge: true));

    return userRank;
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

  Future<void> checkAndShowRankUp(BuildContext context, String newRank) async {
    final prefs = await SharedPreferences.getInstance();
    final prevRank = prefs.getString('user_rank') ?? '1';
    if (int.tryParse(newRank) != null && int.tryParse(prevRank) != null) {
      if (int.parse(newRank) > int.parse(prevRank)) {
        // Show popup
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => RankUpDialog(rank: newRank, rankTitle: _getRankTitle(newRank)),
        );
      }
    }
    // Always update stored rank
    await prefs.setString('user_rank', newRank);
  }

  Future<void> checkRankOnStartup() async {
    final rank = await rankFuture;
    await checkAndShowRankUp(context, rank);
  }

  void refreshRank() {
    setState(() {
      rankFuture = _calculateUserRank();
    });
  }

  Future<void> checkDailyReminders() async {
    try {
      print('🔔 StudyPlansListScreen: checkDailyReminders() called');
      await NotificationService.checkAndShowDailyReminder();
      print('🔔 StudyPlansListScreen: checkDailyReminders() completed');
    } catch (e) {
      print('❌ Error checking daily reminders: $e');
    }
  }

  Future<void> _checkAndShowMotivationPopupAfterAllLoaded() async {
    if (_motivationPopupShown) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (studyPlans.isEmpty) return;
    // Wait for a frame to ensure UI is ready
    await Future.delayed(Duration(milliseconds: 100));
    // Calculate status for all plans (fetch logs for each)
    bool anyBehind = false;
    bool allHappy = true;
    bool anyOnTrack = false;
    int planCount = 0;
    for (final plan in studyPlans) {
      final planId = plan['id'] ?? plan['sessionId'] ?? plan['sessionID'];
      if (planId == null) continue;
      planCount++;
      final logsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('session_logs')
          .where('sessionPlanId', isEqualTo: planId)
          .where('sessionType', isEqualTo: 'study')
          .get();
      final logs = logsSnap.docs.map((doc) => doc.data()).toList();
      int _getInt(dynamic value, int fallback) {
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value) ?? fallback;
        return fallback;
      }
      final now = DateTime.now();
      final pomodoroLength = _getInt(plan['pomodoroLength'], 25);
      final numberOfPomodoros = _getInt(plan['numberOfPomodoros'], 4);
      final sessionsPerDay = _getInt(plan['sessionsPerDay'], 1);
      final selectedDays = (plan['selectedDays'] as List?)?.map((ts) => (ts as Timestamp).toDate()).toList() ?? [];
      final todayDate = DateTime(now.year, now.month, now.day);
      final pastSelectedDaysList = selectedDays.where((d) => d.isBefore(todayDate)).toList();
      final expectedDay = pomodoroLength * numberOfPomodoros * sessionsPerDay;
      final currentExpectedMinutes = expectedDay * pastSelectedDaysList.length;
      final totalActualMinutes = logs.fold<int>(0, (sum, l) => sum + _getInt(l['duration'], 0));
      String status;
      if (pastSelectedDaysList.isEmpty) {
        // If no selected days have passed, but user has studied, they are Ahead
        if (totalActualMinutes > 0) {
          status = 'Ahead';
        } else {
          status = 'On Track';
        }
      } else {
        final currentReadinessScore = currentExpectedMinutes == 0
            ? (totalActualMinutes > 0 ? 100 : 0)
            : (totalActualMinutes / currentExpectedMinutes * 100);
        if (currentReadinessScore > 105) {
          status = 'Ahead';
        } else if (currentReadinessScore >= 95) {
          status = 'On Track';
        } else {
          status = 'Behind';
        }
      }
      if (status == 'Behind') anyBehind = true;
      if (status == 'On Track') anyOnTrack = true;
      if (status != 'Ahead' && status != 'Completed') allHappy = false;
    }
    // Choose icon and message
    String iconPath;
    List<String> messages;
    if (anyBehind) {
      iconPath = 'assets/icon/upset-icon.png';
      messages = [
        "Incredible. You achieved the rare negative productivity.",
        "At this point, the timer's doing more work than you.",
        "You and your goals just filed for separation.",
        "You stared into the void… and the void scrolled Instagram.",
        "I've seen potatoes with better focus.",
        "You opened the app, then ghosted it. Classic.",
        "Even the tomato is questioning its life choices.",
        "Reminder: thinking about doing work is not actually doing work.",
        "If you were trying to break a productivity record—in reverse—you nailed it.",
        "New achievement unlocked: master of majestic avoidance."
      ];
    } else if (allHappy && planCount > 0) {
      iconPath = 'assets/icon/happy-icon.png';
      messages = [
        "Well, look at you! Brain gains detected 🧠💪",
        "Are you studying or casting spells? Because that focus is magical ✨",
        "Another Pomodoro? Who are you and what have you done with the procrastinator?",
        "Alert: Productivity levels dangerously high. Proceed with snacks.",
        "Keep this up and you'll earn a PhD in getting things DONE 🧑‍🎓",
        "You versus distractions: 1-0. Cat approves. ��",
        "Someone's on fire today… Is it the tomato or your brain?",
        "If focus were a sport, you'd be in the Olympics right now.",
        "Hey genius, save some smarts for the rest of us.",
        "Studying like a boss. Tomato cat is mildly impressed 🍅😼"
      ];
    } else if (anyOnTrack) {
      iconPath = 'assets/icon/neutral-icon.png';
      messages = [
        "Wow. You did… a thing. Look at you, existing productively-ish.",
        "Not bad! Not great either… but hey, your chair's proud of you.",
        "That was… acceptable. Gold star in lowercase.",
        "Somewhere between 'meh' and 'okay'. Just like your cooking.",
        "You moved the needle! Just barely, but technically it moved.",
        "A round of applause! (from one very lazy cat)",
        "You're not slacking, you're just… pacing yourself. Forever.",
        "If mediocrity were a sport, you'd be on the podium.",
        "Productivity level: lukewarm soup.",
        "Hey, you did more than nothing. That's… mathematically positive!"
      ];
    } else {
      // fallback: neutral
      iconPath = 'assets/icon/neutral-icon.png';
      messages = [
        "Wow. You did… a thing. Look at you, existing productively-ish.",
        "Not bad! Not great either… but hey, your chair's proud of you.",
        "That was… acceptable. Gold star in lowercase.",
        "Somewhere between 'meh' and 'okay'. Just like your cooking.",
        "You moved the needle! Just barely, but technically it moved.",
        "A round of applause! (from one very lazy cat)",
        "You're not slacking, you're just… pacing yourself. Forever.",
        "If mediocrity were a sport, you'd be on the podium.",
        "Productivity level: lukewarm soup.",
        "Hey, you did more than nothing. That's… mathematically positive!"
      ];
    }
    messages.shuffle();
    String message = messages.first;
    // Show dialog after all calculations are done and UI is ready
    await Future.delayed(Duration(milliseconds: 100));
    if (!_motivationPopupShown) {
      _motivationPopupShown = true;
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _MotivationPopup(iconPath: iconPath, message: message),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Plans',
      customAppBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        leading: null,
        title: Text('Plans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          PopupMenuButton<SortOption>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, color: Colors.white),
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
            onSelected: sortStudyPlans,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              PopupMenuItem<SortOption>(
                value: SortOption.deadline,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: currentSortBy == 'deadline' ? Colors.red : Colors.grey),
                    SizedBox(width: 8),
                    Text('Sort by Deadline'),
                    if (currentSortBy == 'deadline')
                      Icon(
                        isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.red,
                        size: 16,
                      ),
                  ],
                ),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.name,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: currentSortBy == 'name' ? Colors.red : Colors.grey),
                    SizedBox(width: 8),
                    Text('Sort by Name'),
                    if (currentSortBy == 'name')
                      Icon(
                        isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.red,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PairingScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
          Builder(
            builder: (context) {
              final user = FirebaseAuth.instance.currentUser;
              return FutureBuilder<String>(
                future: rankFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    // Show nothing or a loading indicator while loading
                    return SizedBox(width: 32, height: 32);
                  }
                  final rank = snapshot.data ?? "1";
                  return IconButton(
                    icon: Image.asset(
                      'assets/mascots/rank$rank.png',
                      width: 32,
                      height: 32,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => FutureBuilder<String>(
                          future: rankFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return AlertDialog(
                                title: Text('Profile'),
                                content: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Close'),
                                  ),
                                ],
                              );
                            }
                            final rank = snapshot.data ?? "1";
                            return AlertDialog(
                              title: Text('Profile'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/mascots/rank$rank.png',
                                    width: 64,
                                    height: 64,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _getRankTitle(rank),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                  Divider(height: 24),
                                  if (user?.displayName != null)
                                    Text(user!.displayName!, style: TextStyle(fontWeight: FontWeight.bold)),
                                  if (user?.email != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(user!.email!, style: TextStyle(color: Colors.grey[700])),
                                    ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Error: $error'))
              : studyPlans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 80, color: Colors.grey[300]),
                          SizedBox(height: 24),
                          Text(
                            'No study plans available.',
                            style: TextStyle(fontSize: 18, color: Colors.blueGrey[700]),
                          ),
                          SizedBox(height: 32),
                          SizedBox(
                            width: 220,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.add, color: Colors.red),
                              label: Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: navigateToAddPlan,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: studyPlans.length,
                            itemBuilder: (context, index) {
                              final plan = studyPlans[index];
                              return Dismissible(
                                key: Key(plan['id'] ?? index.toString()),
                                direction: DismissDirection.horizontal,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: EdgeInsets.only(left: 20),
                                  color: Colors.blue,
                                  child: Icon(Icons.edit, color: Colors.white),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    final bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Edit Study Plan'),
                                          content: Text('Do you want to edit this study plan?'),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('Edit'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudyPlannerSettingsScreen(existingPlan: plan),
                                        ),
                                      ).then((_) => fetchStudyPlans());
                                    }
                                    return false;
                                  } else {
                                    final bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Delete Study Plan'),
                                          content: Text('Are you sure you want to delete this study plan?'),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('Delete'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true && plan['id'] != null) {
                                      await deleteStudyPlan(plan['id']);
                                    }
                                    return false;
                                  }
                                },
                                child: Card(
                                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () async {
                                      final currentUser = FirebaseAuth.instance.currentUser;
                                      if (currentUser != null && plan['id'] != null && plan['id'] != '') {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExamDashboardScreen(
                                              uid: currentUser.uid,
                                              planId: plan['id'],
                                            ),
                                          ),
                                        );
                                        // After returning, refresh study plans and rank
                                        fetchStudyPlans();
                                        refreshRank();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: Missing user or plan ID')),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListTile(
                                      leading: Icon(Icons.menu_book, color: Colors.red, size: 32),
                                      title: Text(
                                        plan['sessionName'] ?? 'Unnamed Session',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      subtitle: Text(
                                        'Deadline: ${formatDeadline(plan['examDeadline'])}',
                                        style: TextStyle(color: Colors.blueGrey[700]),
                                      ),
                                      trailing: Icon(Icons.arrow_forward_ios, color: Colors.red),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          width: 220,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add, color: Colors.red),
                            label: Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: navigateToAddPlan,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _NavBarItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white),
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class RankUpDialog extends StatelessWidget {
  final String rank;
  final String rankTitle;
  const RankUpDialog({required this.rank, required this.rankTitle});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 48),
          SizedBox(height: 12),
          Text('Congratulations!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          SizedBox(height: 8),
          Text("You've reached a new rank!", style: TextStyle(fontSize: 16)),
          SizedBox(height: 16),
          Image.asset('assets/mascots/rank$rank.png', width: 80, height: 80),
          SizedBox(height: 12),
          Text(
            rankTitle,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Awesome!'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotivationPopup extends StatelessWidget {
  final String iconPath;
  final String message;
  const _MotivationPopup({required this.iconPath, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 40),
                Align(
                  alignment: Alignment.center,
                  child: _ChatBubble(message: message),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(
              child: Image.asset(iconPath, width: 96, height: 96),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.red, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(6),
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 16, color: Colors.red[900], fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
