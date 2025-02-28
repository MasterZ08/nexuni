import 'package:flutter/material.dart';
import '../authentication/AdminLoginPage.dart';
import '../utils/session_manager.dart';
import '../pages/DashBoardContentPage.dart';
import '../pages/EmployeeListPage.dart';
import '../pages/AddEmployeePage.dart';
import '../pages/ReportPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isSidebarVisible = false; // Sidebar is hidden by default
  String _selectedPage = 'Dashboard';
  String first_name = "Loading...";
  String last_name = "Loading...";
  String name = "Loading...";
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child("users").child(user.uid);

      userRef.once().then((DatabaseEvent event) {
        if (event.snapshot.exists) {
          Map<dynamic, dynamic>? userData = event.snapshot.value as Map?;
          if (userData != null) {
            String firstName = userData['first_name'] ?? "Unknown";
            String lastName = userData['last_name'] ?? "User";
            String position = userData['position'] ?? "";

            setState(() {
              first_name = firstName;
              last_name = lastName;
              name = "$firstName $lastName";
            });

            if (position != "Admin") {
              setState(() {
                name = "Access Denied";
              });
            }
          }
        }
      });
    }
  }

  final Map<String, Widget> _pages = {
    'Dashboard': DashboardContentPage(),
    'Employee List': EmployeeListPage(),
    'Add Employee': AddEmployeePage(),
    'Report': ReportPage(),
  };

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Main Content Area
          Padding(
            padding: EdgeInsets.only(
              left: isSidebarVisible && !isMobile ? 250 : 0,
            ),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _pages[_selectedPage] ?? Container(),
            ),
          ),

          // Sidebar
          if (isSidebarVisible)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: isMobile ? screenWidth : 250, // Full width on mobile, fixed width on desktop
              height: MediaQuery.of(context).size.height, // Always full height
              color: Color(0xFF000080),
              child: Column(
                children: [
                  // Drawer Header
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    color: Color(0xFF000080),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 30,
                          child: Icon(Icons.person, color: Colors.black, size: 30),
                        ),
                        SizedBox(height: 10),
                        Text(
                          name,
                          style: TextStyle(color: Colors.white, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(
                            color: Colors.white,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Navigation Buttons
                  _buildNavButton(Icons.dashboard, 'Dashboard'),
                  _buildNavButton(Icons.group, 'Employee List'),
                  _buildNavButton(Icons.add, 'Add Employee'),
                  _buildNavButton(Icons.report, 'Report'),
                  Spacer(),
                  _buildLogoutButton(),
                ],
              ),
            ),

          // No need for a backdrop since the sidebar will cover the entire screen in mobile mode

          // Expander/Collapser Button
          Positioned(
            top: 20,
            left: isSidebarVisible ? (isMobile ? screenWidth - 50 : 250 - 30) : 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isSidebarVisible = !isSidebarVisible;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF000080),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                  ],
                ),
                padding: EdgeInsets.all(10),
                child: Icon(
                  isSidebarVisible ? Icons.close : Icons.menu,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPage = title;
            if (MediaQuery.of(context).size.width < 600) {
              isSidebarVisible = false; // Auto-close on mobile
            }
          });
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: _selectedPage == title ? Colors.white.withOpacity(0.4) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: InkWell(
        onTap: () {
          SessionManager.clearSession();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => AdminLoginPage()),
                (Route<dynamic> route) => false,
          );
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.white),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}