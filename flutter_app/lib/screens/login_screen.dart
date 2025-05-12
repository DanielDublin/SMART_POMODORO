import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'logged_in_screen.dart';
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  String error = '';

  void toggleForm() {
    setState(() {
      isLogin = !isLogin;
      error = '';
    });
  }

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      if (isLogin) {
        await AuthService.signIn(email, password);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoggedInScreen()),
        );
      } else {
        await AuthService.register(email, password);
        setState(() {
          error = 'Registration successful!';
        });
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(
                  color: error.contains('successful') ? Colors.green : Colors.red,
                ),
              ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleAuth,
              child: Text(isLogin ? 'Login' : 'Register'),
            ),
            TextButton(
              onPressed: toggleForm,
              child: Text(isLogin ? 'No account? Register' : 'Have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}