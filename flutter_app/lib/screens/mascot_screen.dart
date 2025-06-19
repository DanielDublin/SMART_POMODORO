import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_plans_list_screen.dart';

class MascotScreen extends StatefulWidget {
  @override
  _MascotScreenState createState() => _MascotScreenState();
}

class _MascotScreenState extends State<MascotScreen> {
  late Future<_RankData> _rankDataFuture;

  @override
  void initState() {
    super.initState();
    _rankDataFuture = _fetchRankData();
  }

  Future<_RankData> _fetchRankData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    
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

    // Calculate rank based on total minutes
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

    return _getRankData(totalMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: Text('Rank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
            (route) => false,
          ),
        ),
      ),
      body: FutureBuilder<_RankData>(
        future: _rankDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
          }
          final data = snapshot.data!;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('RANK ${data.rankIndex + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[700], letterSpacing: 1.2)),
                      SizedBox(height: 8),
                      Text(data.rankName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Colors.blueGrey[900], letterSpacing: 1.2)),
                      SizedBox(height: 16),
                      // Mascot image
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue[50],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            data.assetPath,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.pets, size: 80, color: Colors.blueGrey[700]),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      // Progress bar
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: data.progress,
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.blue[400],
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text('${(data.progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        data.isMaxRank
                          ? 'You reached the highest rank!'
                          : 'Need ${data.minutesToNextRank} min to reach Rank ${data.rankIndex + 2}',
                        style: TextStyle(fontSize: 16, color: Colors.blueGrey[800]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text('Total Minutes: ${data.totalMinutes}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RankData {
  final int rankIndex;
  final String rankName;
  final int totalMinutes;
  final int minutesToNextRank;
  final double progress;
  final bool isMaxRank;
  final String assetPath;
  _RankData({
    required this.rankIndex,
    required this.rankName,
    required this.totalMinutes,
    required this.minutesToNextRank,
    required this.progress,
    required this.isMaxRank,
    required this.assetPath,
  });
}

_RankData _getRankData(int totalMinutes) {
  // Table and asset mapping
  final ranks = [
    {'name': 'Seedling', 'minutes': 0, 'asset': 'assets/mascots/rank1.png'},
    {'name': 'Sprout', 'minutes': 100, 'asset': 'assets/mascots/rank2.png'},
    {'name': 'Apprentice', 'minutes': 300, 'asset': 'assets/mascots/rank3.png'},
    {'name': 'Scholar', 'minutes': 700, 'asset': 'assets/mascots/rank4.png'},
    {'name': 'Researcher', 'minutes': 1500, 'asset': 'assets/mascots/rank5.png'},
    {'name': 'Strategist', 'minutes': 3000, 'asset': 'assets/mascots/rank6.png'},
    {'name': 'Focus Ninja', 'minutes': 5000, 'asset': 'assets/mascots/rank7.png'},
    {'name': 'Mind Master', 'minutes': 8000, 'asset': 'assets/mascots/rank8.png'},
    {'name': 'Study Sage', 'minutes': 12000, 'asset': 'assets/mascots/rank9.png'},
    {'name': 'Pomodoro Pro', 'minutes': 20000, 'asset': 'assets/mascots/rank10.png'},
  ];
  int rankIndex = 0;
  for (int i = 0; i < ranks.length; i++) {
    final minValue = ranks[i]['minutes'];
    if (minValue is int && totalMinutes >= minValue) {
      rankIndex = i;
    } else {
      break;
    }
  }
  final isMaxRank = rankIndex == ranks.length - 1;
  final nextRankMinutes = isMaxRank ? ranks[rankIndex]['minutes'] as int : ranks[rankIndex + 1]['minutes'] as int;
  final minutesToNextRank = isMaxRank ? 0 : (nextRankMinutes - totalMinutes).clamp(0, nextRankMinutes);
  final minForThisRank = ranks[rankIndex]['minutes'] as int;
  final maxForThisRank = isMaxRank ? minForThisRank + 1 : nextRankMinutes;
  final progress = isMaxRank ? 1.0 : ((totalMinutes - minForThisRank) / (maxForThisRank - minForThisRank)).clamp(0.0, 1.0);
  final assetPath = ranks[rankIndex]['asset'] as String;
  return _RankData(
    rankIndex: rankIndex,
    rankName: ranks[rankIndex]['name'] as String,
    totalMinutes: totalMinutes,
    minutesToNextRank: minutesToNextRank,
    progress: progress,
    isMaxRank: isMaxRank,
    assetPath: assetPath,
  );
} 