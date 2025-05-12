import 'package:flutter/material.dart';

class LoggedInScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome')),
      body: Center(
        child: Text(
          'You are logged in!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}