import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nexuni/pages/EmployeeListPage.dart';

// Define a global navigator key to use across the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Define your routes
final Map<String, WidgetBuilder> routes = {
  '/': (context) => MainLayout(child: DashboardContentPage()),
  '/employees': (context) => MainLayout(child: EmployeeListPage()),
  // Add other routes as needed
};

// Main layout that includes the navigation drawer
class MainLayout extends StatefulWidget {
  final Widget child;

  MainLayout({required this.child});

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isDrawerExpanded = true;

  void _toggleDrawer() {
    setState(() {
      _isDrawerExpanded = !_isDrawerExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation drawer
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: _isDrawerExpanded ? 250 : 70,
            color: Colors.blue[900],
            child: Column(
              children: [
                // Drawer header with toggle button
                Container(
                  height: 60,
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      _isDrawerExpanded ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                      color: Colors.white,
                    ),
                    onPressed: _toggleDrawer,
                  ),
                ),
                // Navigation items
                _buildNavItem(Icons.dashboard, 'Dashboard', () {
                  Navigator.pushReplacementNamed(context, '/');
                }),
                _buildNavItem(Icons.people, 'Employees', () {
                  Navigator.pushReplacementNamed(context, '/employees');
                }),
                // Add more navigation items as needed
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  // Helper method to build navigation items
  Widget _buildNavItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            if (_isDrawerExpanded) ...[
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardContentPage extends StatefulWidget {
  @override
  _DashboardContentPageState createState() => _DashboardContentPageState();
}

class _DashboardContentPageState extends State<DashboardContentPage> {
  int totalEmployees = 0;

  @override
  void initState() {
    super.initState();
    _fetchTotalEmployees();
  }

  Future<void> _fetchTotalEmployees() async {
    DatabaseReference usersRef = FirebaseDatabase.instance.ref().child('users_acc');

    usersRef.once().then((DatabaseEvent event) {
      if (event.snapshot.exists) {
        setState(() {
          totalEmployees = event.snapshot.children.length;
        });
      } else {
        setState(() {
          totalEmployees = 0; // If no users, show 0
        });
      }
    }).catchError((error) {
      print('Error fetching total employees: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen width to determine if we're on mobile or desktop
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.blueGrey[100], // Background color
      child: Column(
        children: [
          // Responsive header section
          isMobile
              ? _buildMobileHeader()
              : _buildDesktopHeader(),

          SizedBox(height: 20), // Spacing before the grid

          // Modified to take 75% of available space
          Expanded(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.75, // Take 75% of the width
                heightFactor: 0.75, // Take 75% of the height
                child: _buildClickableDashboardCard(
                    Icons.group,
                    'Total Employees',
                    totalEmployees.toString(),
                    context
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile header with centered elements
  Widget _buildMobileHeader() {
    return Column(
      children: [
        // NEXUNI logo (centered)
        _buildNexuniLogo(),
        SizedBox(height: 15),
        // Dashboard Overview text (centered)
        Text(
          'Dashboard Overview',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Desktop header with adjusted layout
  Widget _buildDesktopHeader() {
    return Row(
      children: [
        // Increased spacing to move Dashboard Overview further to the right
        SizedBox(width: 80), // Increased from 50 to move text more to the right
        // Dashboard Overview text
        Expanded(
          flex: 2,
          child: Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // NEXUNI logo (centered)
        Expanded(
          flex: 3,
          child: Center(
            child: _buildNexuniLogo(),
          ),
        ),
        // Empty space to balance the header
        Expanded(flex: 2, child: Container()),
      ],
    );
  }

  // NEXUNI logo widget
  Widget _buildNexuniLogo() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'NEX',
            style: TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          TextSpan(
            text: 'UNI',
            style: TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900], // Navy blue color
            ),
          ),
        ],
      ),
    );
  }

  // Clickable Card for Total Employees - Updated to use named routes
  Widget _buildClickableDashboardCard(IconData icon, String title, String value, BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Instead of pushing a new route, use named routes with pushReplacement
        Navigator.pushReplacementNamed(context, '/employees');
      },
      child: _buildDashboardCard(icon, title, value),
    );
  }

  Widget _buildDashboardCard(IconData icon, String title, String value) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueGrey),
            SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
            ),
          ],
        ),
      ),
    );
  }
}