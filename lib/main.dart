import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nexuni/pages/DashBoardPage.dart';
import 'package:nexuni/pages/HomePage.dart';
import 'authentication/AdminLoginPage.dart';
import 'authentication/UserLoginPage.dart';

// Add your Firebase config here
const firebaseConfig = {
  'apiKey': "AIzaSyAj_iSOeJ4_e_0DgJtVwjVVXKhzuuhnHa8",
  'authDomain': "nexuni-48c6b.firebaseapp.com",
  'databaseURL': "https://nexuni-48c6b-default-rtdb.asia-southeast1.firebasedatabase.app",
  'projectId': "nexuni-48c6b",
  'storageBucket': "nexuni-48c6b.firebasestorage.app",
  'messagingSenderId': "185600710189",
  'appId': "1:185600710189:web:7a3e0892836b7a21b70aa4",
  'measurementId': "G-77N7Z81QNN",
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: firebaseConfig['apiKey']!,
      authDomain: firebaseConfig['authDomain']!,
      databaseURL: firebaseConfig['databaseURL']!,
      projectId: firebaseConfig['projectId']!,
      storageBucket: firebaseConfig['storageBucket']!,
      messagingSenderId: firebaseConfig['messagingSenderId']!,
      appId: firebaseConfig['appId']!,
      measurementId: firebaseConfig['measurementId']!,
    ),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Set your own condition to check whether the user is an admin or user
  final bool isUser = true;  // Change this condition based on your needs

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    runApp(MyApp());
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexuni',
      debugShowCheckedModeBanner: false,
      home:isUser ?  UserLoginPage() : AdminLoginPage() ,  // Show Admin or User Login page
    );
  }
}
