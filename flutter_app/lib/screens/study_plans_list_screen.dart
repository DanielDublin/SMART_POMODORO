import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_scaffold.dart';
import '../services/firestore_service.dart';
import '../services/mock_data_service.dart';
import 'study_planner_settings_screen.dart';
import 'exam_dashboard_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

enum SortOption {
  deadline,
  name
}

class StudyPlansListScreen extends StatefulWidget {
  @override
  _StudyPlansListScreenState createState() => _StudyPlansListScreenState();
}

class _StudyPlansListScreenState extends State<StudyPlansListScreen> {
  List<Map<String, dynamic>> studyPlans = [];
  bool isLoading = true;
  String? error;
  bool isConfirmingDelete = false;
  bool isConfirmingEdit = false;
  bool isGeneratingMockData = false;
  String currentSortBy = 'deadline';
  bool isAscending = true;

  void sortStudyPlans(SortOption option) {
    setState(() {
      if (currentSortBy == option.toString().split('.').last) {
        isAscending = !isAscending;
      } else {
        isAscending = true;
      }
      switch (option) {
        case SortOption.deadline:
          studyPlans.sort((a, b) {
            final aDeadline = a['examDeadline'] as Timestamp?;
            final bDeadline = b['examDeadline'] as Timestamp?;
            if (aDeadline == null && bDeadline == null) return 0;
            if (aDeadline == null) return 1;
            if (bDeadline == null) return -1;
            return isAscending ? aDeadline.compareTo(bDeadline) : bDeadline.compareTo(aDeadline);
          });
          currentSortBy = 'deadline';
          break;
        case SortOption.name:
          studyPlans.sort((a, b) {
            final aName = (a['sessionName'] ?? '').toString().toLowerCase();
            final bName = (b['sessionName'] ?? '').toString().toLowerCase();
            return isAscending ? aName.compareTo(bName) : bName.compareTo(aName);
          });
          currentSortBy = 'name';
          break;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    fetchStudyPlans();
  }

  Future<void> fetchStudyPlans() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      
      final sessions = await FirestoreService.getStudySessions();
      setState(() {
        studyPlans = sessions;
        switch (currentSortBy) {
          case 'deadline':
            sortStudyPlans(SortOption.deadline);
            break;
          case 'name':
            sortStudyPlans(SortOption.name);
            break;
        }
        isLoading = false;
      });
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
      await FirestoreService.deleteStudySession(planId);
      await fetchStudyPlans(); // Refresh the list
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
    return CustomScaffold(
      title: 'My Study Plans',
      customAppBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        leading: null,
        title: Text('My Study Plans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
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
                future: _calculateUserRank(),
                builder: (context, snapshot) {
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
                          future: _calculateUserRank(),
                          builder: (context, snapshot) {
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
                          child: ReorderableListView.builder(
                            itemCount: studyPlans.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = studyPlans.removeAt(oldIndex);
                                studyPlans.insert(newIndex, item);
                              });
                            },
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
                                      await FirestoreService.deleteStudySession(plan['id']);
                                      await fetchStudyPlans();
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExamDashboardScreen(
                                              uid: currentUser.uid,
                                              planId: plan['id'],
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: Missing user or plan ID')),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListTile(
                                      leading: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.drag_handle, color: Colors.grey),
                                          SizedBox(width: 8),
                                          Icon(Icons.menu_book, color: Colors.red, size: 32),
                                        ],
                                      ),
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
