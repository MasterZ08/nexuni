import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:nexuni/authentication/AdminLoginPage.dart';
import 'package:nexuni/pages/HomePage.dart'; // Replace with the actual home page for Employees

class UserLoginPage extends StatefulWidget {
  @override
  _UserLoginPageState createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('users_acc');
  bool _isLoading = false;
  late FocusNode _focusNode;
  final FocusNode _emailFocusNode = FocusNode(); // Focus node for email input
  final FocusNode _passwordFocusNode = FocusNode(); // Focus node for password input

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(); // Initialize the focus node
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Dispose the focus node when the widget is disposed
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _resetPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController emailController = TextEditingController();

        return AlertDialog(
          title: const Text(
            'Forgot Password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter your registered email to receive a password reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.blue),
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _sendPasswordResetEmail(emailController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }


  void _sendPasswordResetEmail(String email) {
    if (email.isEmpty) {
      _showMessageDialog("Error", "Please enter your email address.");
      return;
    }

    _auth.sendPasswordResetEmail(email: email).then((_) {
      Navigator.of(context).pop(); // Close the input dialog first
      _showMessageDialog("Success", "A password reset link has been sent to $email.");
    }).catchError((error) {
      _showMessageDialog("Error", "Failed to send reset email. Please try again.");
    });
  }

  void _showMessageDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: title == "Success" ? Colors.green : Colors.red)),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: <Widget>[
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Authenticate user
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user == null) {
        _showErrorDialog('Login Failed', 'User authentication failed.');
        return;
      }

      String uid = userCredential.user!.uid;

      // Fetch user data from Realtime Database
      DatabaseEvent event = await _dbRef.child(uid).once();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(snapshot.value as Map);

        print("Fetched User Data: $userData"); // Debugging Line

        String position = userData['position'] ?? '';
        bool isVerified = userData['verified'] == true; // Ensure boolean comparison

        if (!isVerified) {
          _showErrorDialog('Email Not Verified', 'Please verify your email before logging in.');
          await _auth.signOut();
          return;
        }

        if (position == 'Admin') {
          _showErrorDialog('Access Denied', 'Admins are not allowed to log in here.');
          await _auth.signOut();
        } else if (position == 'Employee') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(userEmail: _emailController.text.trim()),
            ),
          );
        } else {
          _showErrorDialog('Invalid Position', 'Your position is not recognized.');
          await _auth.signOut();
        }
      } else {
        _showErrorDialog('Error', 'User data not found.');
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog('Login Failed', e.message ?? 'An unknown error occurred.');
    } finally {
      setState(() => _isLoading = false);
    }
  }



  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text(
              'Error',
              style: TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              side: BorderSide(color: Colors.red), // Red border
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/nexuni2.jpg',
            fit: BoxFit.cover,
          ),
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/nexuni.png',
                    width: 100,  // Adjust width
                    height: 100, // Adjust height
                    fit: BoxFit.contain, // Adjust fit if necessary
                  ),

                  SizedBox(height: 10),
                  Text('Login', style: TextStyle(fontSize: 24, color: Colors.black)),
                  SizedBox(height: 20),
                  RawKeyboardListener(
                    focusNode: _focusNode, // Use focus node for keyboard listener
                    autofocus: true,
                    onKey: (RawKeyEvent event) {
                      if (event is RawKeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        _login(); // Trigger login when Enter is pressed
                      }
                    },
                    child: Column(
                      children: [
                        TextField(
                          focusNode: _emailFocusNode, // Set focus node for email input
                          controller: _emailController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.person, color: Colors.black),
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.black),
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          focusNode: _passwordFocusNode, // Set focus node for password input
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.key, color: Colors.black),
                            labelText: 'Password',
                            labelStyle: TextStyle(color: Colors.black),
                            hintText: 'Enter your password',
                            hintStyle: TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AdminLoginPage()),
                      );
                    },
                    child: const Text(
                      'Not an user? Login as admin',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _resetPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}