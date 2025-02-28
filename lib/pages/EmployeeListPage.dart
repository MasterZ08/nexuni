import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // For date formatting

class EmployeeListPage extends StatefulWidget {
  @override
  _EmployeeListPageState createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  late DatabaseReference _userRef;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();
  Map<String, Map<String, String>> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _userRef = FirebaseDatabase.instance.ref('users_acc');
    _fetchEmployeeData();
  }

  void _fetchEmployeeData() async {
    try {
      DataSnapshot snapshot = await _userRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> employeesList = [];

        data.forEach((key, value) {
          if (value != null && value['password'] == null) {
            employeesList.add({
              'key': key,
              'first_name': value['first_name'] ?? 'Unknown',
              'middle_name': value['middle_name'] ?? '',
              'last_name': value['last_name'] ?? 'User',
              'mobile_number': value['mobile_number'] ?? 'N/A',
              'position': value['position'] ?? 'N/A',
              'employee_id': value['employee_id'] ?? 'N/A',
              'email': value['email'] ?? 'N/A',
            });
          }
        });

        setState(() {
          _employees = employeesList;
          _filteredEmployees = employeesList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAttendanceDialog(BuildContext context, String userId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch attendance records for the specific user
      DatabaseReference attendanceRef =
      FirebaseDatabase.instance.ref().child('attendance').child(userId);

      DataSnapshot snapshot = await attendanceRef.get();

      Navigator.pop(context); // Close loading dialog

      if (!snapshot.exists) {
        _showNoDataDialog(context);
        return;
      }

      Map<dynamic, dynamic> attendanceData =
      snapshot.value as Map<dynamic, dynamic>;

      // Show the data in a dialog
      _showAttendanceDetailsDialog(context, attendanceData);
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, e.toString());
    }
  }

  void _showAttendanceDetailsDialog(
      BuildContext context, Map<dynamic, dynamic> attendanceData) {
    List<Map<String, dynamic>> sortedAttendance = attendanceData.entries
        .map((entry) {
      var record = entry.value as Map<dynamic, dynamic>;
      return {
        'date': record['date'] ?? 'N/A',
        'time_in': record['time_in'] ?? 'N/A',
        'time_out': record['time_out'] ?? 'N/A',
      };
    })
        .where((record) => record['date'] != 'N/A') // Ensure valid dates
        .toList();

    sortedAttendance.sort((a, b) {
      DateTime dateA = DateFormat('dd/MM/yyyy').parse(a['date']!);
      DateTime dateB = DateFormat('dd/MM/yyyy').parse(b['date']!);
      return dateB.compareTo(dateA); // Newest first
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Attendance Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Time In', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Time Out', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                Divider(thickness: 1),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedAttendance.length,
                    itemBuilder: (context, index) {
                      var record = sortedAttendance[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(child: Text('${index + 1}')),
                            Expanded(child: Text(record['date']!)),
                            Expanded(child: Text(record['time_in']!)),
                            Expanded(child: Text(record['time_out']!)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("No Attendance Records"),
          content: Text("No attendance data found for this user."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _filterEmployees(String query) {
    setState(() {
      _filteredEmployees = _employees
          .where((employee) =>
          ('${employee['first_name']} ${employee['middle_name']} ${employee['last_name']}')
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _filteredEmployees = _employees;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: isMobile, // Only show back button in mobile mode
        toolbarHeight: isMobile ? 100 : 80, // Increased height for mobile
        centerTitle: isMobile ? true : false, // Center title only in mobile mode
        title: isMobile
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 10), // Add space at top for mobile
            Text(
              'Employee List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'NEX',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  TextSpan(
                    text: 'UNI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center the row contents
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Added space at the start to push "Employee List" to the right
            SizedBox(width: 100),
            Text(
              'Employee List',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Increased space between "Employee List" and "NEXUNI"
            Expanded(child: SizedBox()), // This pushes NEXUNI to center
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
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
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: SizedBox()), // Balance the layout
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _clearSearch,
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: EmployeeSearchDelegate(
                  _employees,
                  _filterEmployees,
                  _clearSearch,
                  isMobile,
                ),
              );
            },
          ),
          SizedBox(width: 8), // Add some padding after the last icon
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03,
            vertical: 16,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive grid layout
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;

              // Adjust child aspect ratio based on available width
              final childAspectRatio = isMobile
                  ? 1.8
                  : constraints.maxWidth > 1200
                  ? 2.5
                  : 2.2;

              return GridView.builder(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _filteredEmployees.length,
                itemBuilder: (context, index) {
                  final employee = _filteredEmployees[index];
                  return GestureDetector(
                    onTap: () {
                      _showAttendanceDialog(context, employee['key']);
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: isMobile ? 50 : 70,
                              height: isMobile ? 50 : 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade200,
                              ),
                              child: Icon(
                                Icons.account_circle,
                                size: isMobile ? 50 : 70,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${employee['first_name']} ${employee['middle_name']} ${employee['last_name']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'ID: ${employee['employee_id']}',
                                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                                  ),
                                  Text(
                                    employee['position'],
                                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Mobile: ${employee['mobile_number']}',
                                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                                  ),
                                  Text(
                                    'Email: ${employee['email']}',
                                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class EmployeeSearchDelegate extends SearchDelegate<String?> {
  final List<Map<String, dynamic>> employees;
  final Function(String) onSearch;
  final VoidCallback onClear;
  final bool isMobile;

  EmployeeSearchDelegate(this.employees, this.onSearch, this.onClear, this.isMobile);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          showResults(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    // Removed the back arrow button for both mobile and PC
    return Container();
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    return _buildSuggestionsList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestionsList();
  }

  Widget _buildSuggestionsList() {
    final filteredList = employees
        .where((employee) =>
        ('${employee['first_name']} ${employee['middle_name']} ${employee['last_name']}')
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final employee = filteredList[index];
        return ListTile(
          leading: Icon(Icons.account_circle, size: isMobile ? 30 : 40),
          title: Text(
            '${employee['first_name']} ${employee['middle_name']} ${employee['last_name']}',
            style: TextStyle(fontSize: isMobile ? 14 : 16),
          ),
          subtitle: Text(
            employee['position'],
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
          onTap: () {
            onSearch('${employee['first_name']} ${employee['middle_name']} ${employee['last_name']}');
            close(context, null);
          },
        );
      },
    );
  }
}