import 'package:flutter/material.dart';

class SessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;

  const SessionScreen({
    Key? key,
    required this.sessionData,
  }) : super(key: key);

  @override
  _SessionScreenState createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionData['sessionName'] ?? 'Session'),
      ),
      body: Center(
        child: Text('Session details will be implemented here'),
      ),
    );
  }
} 