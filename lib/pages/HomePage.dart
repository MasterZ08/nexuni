import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../authentication/UserLoginPage.dart';
import 'EditProfilePage.dart';
import 'LogPage.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required String userEmail}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showLog = false;
  bool showEditProfile = false;
  bool isSidebarVisible = false; // Sidebar is hidden by default
  String firstName = "Loading...";
  String fullName = "Loading...";
  String email = "Loading...";
  String employeeId = "Loading...";
  String position = "Loading...";
  int? touchedIndex; // Track which pie section is touched

  // Use a more efficient way to store attendance data
  final Map<String, int> attendanceSummary = {
    'Present': 0,
    'Late': 0,
    'Overtime': 0,
    'Early Out': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final DatabaseReference attendanceRef = FirebaseDatabase.instance.ref()
        .child("attendance")
        .child(user.uid);

    try {
      final DatabaseEvent event = await attendanceRef.once();
      if (!event.snapshot.exists) return;

      final Map<dynamic, dynamic> records = event.snapshot.value as Map<dynamic, dynamic>;

      // Create a temporary map to avoid multiple setState calls
      final Map<String, int> tempSummary = {
        'Present': 0,
        'Late': 0,
        'Overtime': 0,
        'Early Out': 0,
      };

      records.forEach((key, value) {
        final String timeIn = value['time_in'] ?? '';
        final String timeOut = value['time_out'] ?? '';

        if (timeIn.isNotEmpty && timeOut.isNotEmpty) {
          final TimeOfDay timeInParsed = _parseTime(timeIn);
          final TimeOfDay timeOutParsed = _parseTime(timeOut);

          if (timeInParsed.hour >= 9 && timeInParsed.minute >= 16) {
            tempSummary['Late'] = tempSummary['Late']! + 1;
          } else {
            tempSummary['Present'] = tempSummary['Present']! + 1;
          }

          if (timeOutParsed.hour > 18 ||
              (timeOutParsed.hour == 18 && timeOutParsed.minute > 59)) {
            tempSummary['Overtime'] = tempSummary['Overtime']! + 1;
          } else if (timeOutParsed.hour < 18) {
            tempSummary['Early Out'] = tempSummary['Early Out']! + 1;
          }
        }
      });

      if (mounted) {
        setState(() {
          attendanceSummary.clear();
          attendanceSummary.addAll(tempSummary);
        });
      }
    } catch (error) {
      print("❌ Error fetching attendance data: $error");
    }
  }

  TimeOfDay _parseTime(String time) {
    final List<String> parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("❌ No user is logged in. Try signing in again.");
      return;
    }

    final DatabaseReference userRef = FirebaseDatabase.instance.ref()
        .child("users_acc")
        .child(user.uid);

    try {
      final DatabaseEvent event = await userRef.once();

      if (event.snapshot.exists) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(
            event.snapshot.value as Map);

        if (mounted) {
          setState(() {
            firstName = userData['first_name'] ?? "User";
            fullName = "${userData['first_name']} ${userData['last_name']}";
            email = userData['email'] ?? "N/A";
            employeeId = userData['employee_id'] ?? "N/A";
            position = userData['position'] ?? "N/A";
          });
        }
      } else {
        print("❌ No user data found in users_acc for UID: ${user.uid}");
      }
    } catch (error) {
      print("❌ Error fetching user data: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar (Expands fully on mobile)
              if (isSidebarVisible)
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: isMobile ? screenWidth : 250,
                  // Full width on mobile
                  height: MediaQuery.of(context).size.height,
                  // Full height
                  color: Color(0xFF28527A),
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: AssetImage('assets/profile.jpg'),
                        child: Icon(
                            Icons.person, size: 40, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 10),
                      Text(fullName, style: TextStyle(color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                      Text(email, style: TextStyle(color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                      Text('ID: $employeeId', style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                      Text(position, style: TextStyle(color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                      Divider(color: Colors.white, thickness: 3),
                      SizedBox(height: 20),
                      _buildSidebarItem(Icons.dashboard, "Dashboard", () {
                        setState(() {
                          showLog = false;
                          showEditProfile = false;
                          if (isMobile)
                            isSidebarVisible = false; // Auto-close on mobile
                        });
                      }, isSelected: !showLog && !showEditProfile),
                      _buildSidebarItem(Icons.article, "Log", () {
                        setState(() {
                          showLog = true;
                          showEditProfile = false;
                          if (isMobile) isSidebarVisible = false;
                        });
                      }, isSelected: showLog),
                      _buildSidebarItem(Icons.edit, "Edit Profile", () {
                        setState(() {
                          showLog = false;
                          showEditProfile = true;
                          if (isMobile) isSidebarVisible = false;
                        });
                      }, isSelected: showEditProfile),
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => UserLoginPage()),
                                  (route) => false,
                            );
                          },
                          icon: Icon(Icons.logout, color: Colors.white),
                          label: Text("Logout", style: TextStyle(color: Colors
                              .white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: showLog
                      ? LogPage()
                      : showEditProfile
                      ? EditProfilePage()
                      : _buildWelcomeText(),
                ),
              ),
            ],
          ),

          // **Backdrop to Close Sidebar on Mobile** (Fixes dark overlay issue)
          if (isMobile && isSidebarVisible)
            Positioned(
              left: screenWidth * 0.75,
              // Only cover the screen outside sidebar
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isSidebarVisible = false;
                  });
                },
                child: Container(
                  color: Colors.transparent, // No black overlay issue
                ),
              ),
            ),

          // **Expander/Collapser Button (Moved to Top Left)**
          Positioned(
            top: 20, // Positioned at the top
            left: isSidebarVisible ? (isMobile ? screenWidth - 70 : 230) : 20, // Positioned at the left
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isSidebarVisible = !isSidebarVisible;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2))
                  ],
                ),
                padding: EdgeInsets.all(10),
                child: Icon(
                  isSidebarVisible ? Icons.close : Icons.menu,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, VoidCallback onTap,
      {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: TextStyle(color: Colors.white)),
        selected: isSelected,
        selectedTileColor: Colors.blue[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWelcomeText() {
    final double totalRecords = attendanceSummary.values.fold(0, (sum, value) => sum + value);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600; // Mobile breakpoint

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Row (or Column on Mobile)
            isMobile
                ? Column( // Stack on mobile
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Center the "Welcome, First Name" text on mobile
                Center(
                  child: Text(
                    'Welcome, $firstName!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'NEX',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      TextSpan(
                        text: 'UNI',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900], // Navy blue
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : Row( // Side-by-side on larger screens
              children: [
                const SizedBox(width: 60), // Added padding on the left to move welcome text right
                Flexible(
                  child: Text(
                    'Welcome, $firstName!',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(), // Pushes "NEXUNI" to center
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
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
                          color: Colors.blue[900], // Navy blue
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(), // Ensures proper centering
              ],
            ),

            SizedBox(height: isMobile ? 20 : 30),

            // Lazy-loading chart with better performance
            totalRecords > 0 ? _buildPieChartSection(isMobile) : _buildNoPieChartPlaceholder(isMobile),

            const SizedBox(height: 20),

            // Memoize the legend to avoid rebuilding
            _buildAttendanceLegend(isMobile),

            const SizedBox(height: 20),

            // Attendance Performance Card - with performance optimizations
            _buildPerformanceCard(isMobile, totalRecords),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPieChartPlaceholder(bool isMobile) {
    return Center(
      child: Container(
        height: isMobile ? 250 : 350,
        width: isMobile ? 250 : 350,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            "No Data",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartSection(bool isMobile) {
    return Center(
      child: SizedBox(
        height: isMobile ? 250 : 350,
        width: isMobile ? 250 : 350,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: _buildPieChartSections(),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceLegend(bool isMobile) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: attendanceSummary.keys.map((category) {
        final int index = attendanceSummary.keys.toList().indexOf(category);
        final bool isSelected = index == touchedIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              touchedIndex = isSelected ? -1 : index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? _getCategoryColor(category).withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _getCategoryColor(category) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerformanceCard(bool isMobile, double totalRecords) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "📊 Attendance Performance",
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 15),

            totalRecords > 0
                ? Column(
              children: attendanceSummary.entries.map((entry) {
                double percentage = (entry.value / totalRecords) * 100;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _getIconForRemark(entry.key),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        "${percentage.toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
                : Text(
              "No attendance records found.",
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to return an icon based on the attendance remark
  Widget _getIconForRemark(String remark) {
    switch (remark) {
      case "Late":
        return const Icon(Icons.access_time, color: Colors.orange, size: 24);
      case "Present":
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case "Overtime":
        return const Icon(Icons.timer, color: Colors.blue, size: 24);
      case "Early Out":
        return const Icon(Icons.exit_to_app, color: Colors.red, size: 24);
      default:
        return const Icon(Icons.info, color: Colors.grey, size: 24);
    }
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final double totalRecords = attendanceSummary.values.fold(0, (sum, value) => sum + value);
    if (totalRecords == 0) {
      // Return a placeholder section if no data
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 100,
          title: 'No Data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        )
      ];
    }

    final List<String> categories = attendanceSummary.keys.toList();

    return List.generate(attendanceSummary.length, (i) {
      final isTouched = i == touchedIndex;
      final double fontSize = isTouched ? 18 : 16;
      final double radius = isTouched ? 80 : 70;

      final String category = categories[i];
      final int value = attendanceSummary[category] ?? 0;
      final double percentage = (value / totalRecords) * 100;

      return PieChartSectionData(
        color: _getCategoryColor(category),
        value: value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 2,
              color: Colors.black26,
              offset: Offset(1, 1),
            ),
          ],
        ),
        badgeWidget: isTouched
            ? _Badge(
          category,
          size: 40,
          borderColor: _getCategoryColor(category),
          showFullLabel: true,
        )
            : null,
        badgePositionPercentageOffset: 1.1,
        titlePositionPercentageOffset: 0.55,
      );
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Present':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      case 'Overtime':
        return Colors.blue;
      case 'Early Out':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Badge widget to show when a section is selected
class _Badge extends StatelessWidget {
  final String category;
  final double size;
  final Color borderColor;
  final bool showFullLabel;

  const _Badge(
      this.category, {
        required this.size,
        required this.borderColor,
        this.showFullLabel = false,
      });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: showFullLabel ? null : size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(showFullLabel ? 15 : 50),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Center(
        child: Text(
          showFullLabel ? category : category.substring(0, 1),
          style: TextStyle(
            color: borderColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}