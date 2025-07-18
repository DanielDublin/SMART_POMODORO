import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'study_plans_list_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _registerEmailController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();
  final TextEditingController _registerConfirmController = TextEditingController();
  String error = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        error = '';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  String? validateEmail(String email) {
    if (email.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+ ?$');
    if (!emailRegex.hasMatch(email)) return 'Please enter a valid email';
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> handleAuth() async {
    setState(() => isLoading = true);
    String? validationError;
    if (_tabController.index == 0) {
      // LOGIN
      validationError = validateEmail(_emailController.text.trim()) ?? validatePassword(_passwordController.text);
    } else {
      // REGISTER
      validationError = validateEmail(_registerEmailController.text.trim()) ?? validatePassword(_registerPasswordController.text);
      if (_registerPasswordController.text != _registerConfirmController.text) {
        validationError = 'Passwords do not match';
      }
    }
    if (validationError != null) {
      setState(() {
        error = validationError!;
        isLoading = false;
      });
      return;
    }
    try {
      if (_tabController.index == 0) {
        await AuthService.signIn(_emailController.text.trim(), _passwordController.text.trim());
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
        );
      } else {
        await AuthService.register(_registerEmailController.text.trim(), _registerPasswordController.text.trim());
        _registerEmailController.clear();
        _registerPasswordController.clear();
        _registerConfirmController.clear();
        setState(() {
          _tabController.animateTo(0);
          error = 'Registration successful! Please login.';
          isLoading = false;
        });
      }
    } catch (e) {
      String userError = 'An error occurred. Please try again.';
      final msg = e.toString();
      if (msg.contains('user-not-found')) userError = 'No account found for that email.';
      else if (msg.contains('wrong-password')) userError = 'Incorrect password.';
      else if (msg.contains('email-already-in-use')) userError = 'Email is already registered.';
      else if (msg.contains('invalid-email')) userError = 'Invalid email address.';
      else if (msg.contains('network-request-failed')) userError = 'Network error. Please check your connection.';
      setState(() {
        error = userError;
        isLoading = false;
      });
    }
  }

  Future<void> handleGoogleSignIn() async {
    setState(() => isLoading = true);
    try {
      final userCredential = await AuthService.signInWithGoogle();
      if (userCredential != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudyPlansListScreen()),
        );
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 350,
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, color: Colors.red, size: 64),
                SizedBox(height: 12),
                Text(
                  'Smart Pomodoro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                SizedBox(height: 24),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.red,
                  labelColor: Colors.red[800],
                  unselectedLabelColor: Colors.blueGrey[700],
                  tabs: [
                    Tab(text: 'LOGIN'),
                    Tab(text: 'REGISTER'),
                  ],
                ),
                SizedBox(height: 16),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: error.contains('successful') ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 340,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // LOGIN TAB
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.email, color: Colors.red),
                                hintText: 'Email',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock, color: Colors.red),
                                hintText: 'Password',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isLoading ? null : handleGoogleSignIn,
                                icon: Image.asset(
                                  'assets/icon/google.png',
                                  width: 20,
                                  height: 20,
                                ),
                                label: Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // REGISTER TAB
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 8),
                            TextField(
                              controller: _registerEmailController,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.email, color: Colors.red),
                                hintText: 'Email',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _registerPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock, color: Colors.red),
                                hintText: 'Password',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _registerConfirmController,
                              obscureText: true,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.red),
                                hintText: 'Confirm Password',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('REGISTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isLoading ? null : handleGoogleSignIn,
                                icon: Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                                  width: 20,
                                  height: 20,
                                ),
                                label: Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_tabController.index == 0) ...[
                      Text('No account?'),
                      TextButton(
                        onPressed: () {
                          _tabController.animateTo(1);
                        },
                        child: Text('Register here', style: TextStyle(color: Colors.red)),
                      ),
                    ] else ...[
                      Text('Already have an account?'),
                      TextButton(
                        onPressed: () {
                          _tabController.animateTo(0);
                        },
                        child: Text('Login here', style: TextStyle(color: Colors.red)),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}