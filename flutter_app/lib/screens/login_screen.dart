import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'study_plans_list_screen.dart';
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;
  String error = '';

  void toggleForm() {
    setState(() {
      isLogin = !isLogin;
      error = '';
    });
  }

  Future<void> handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (isLogin) {
        await AuthService.signIn(email, password);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
        );
      } else {
        await AuthService.register(email, password);
        _emailController.clear();
        _passwordController.clear();
        setState(() {
          isLogin = true;
          error = 'Registration successful!, Login';
        });
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> handleGoogleSignIn() async {
    try {
      await AuthService.signInWithGoogle();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
      );
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0, // This accounts for the keyboard
        ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Adds space from top
              Center(
                child: Text(
                  isLogin ? 'Login' : 'Register',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (error.isNotEmpty)
                Text(
                  error,
                  style: TextStyle(
                    color: error.contains('successful') ? Colors.green : Colors.red,
                  ),
                ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordController,
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
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.login),
                label: Text('Continue with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  side: BorderSide(color: Colors.grey),
                ),
                onPressed: handleGoogleSignIn,
              ),
            ],
          ),
        ),
      );
  }

}