import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';


class LogPage extends StatefulWidget {
  @override
  _LogPageState createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  DateTime? selectedDate;
  List<Map<String, String>> attendanceData = [];
  bool isLoading = true;
  bool isTimeInCooldown = false;
  bool isTimeOutCooldown = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
    _checkCooldown();
  }

  Future<void> _fetchAttendanceData() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    DatabaseReference attendanceRef = _database.child('attendance/${user.uid}');
    attendanceRef.once().then((DatabaseEvent event) {
      final snapshot = event.snapshot;
      if (snapshot.exists) {
        List<Map<String, String>> fetchedData = [];

        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          String date = value['date'] ?? 'N/A';
          String timeIn = value['time_in'] ?? 'N/A';
          String timeOut = value['time_out'] ?? 'N/A';
          String remarks = "Absent";

          if (timeIn != 'N/A' && timeOut != 'N/A') {
            try {
              DateTime timeInParsed = DateFormat('HH:mm').parse(timeIn);
              DateTime timeOutParsed = DateFormat('HH:mm').parse(timeOut);
              DateTime lateThreshold = DateFormat('HH:mm').parse("09:16");
              DateTime earlyOutThreshold = DateFormat('HH:mm').parse("18:00");
              DateTime overtimeThreshold = DateFormat('HH:mm').parse("18:59");

              bool isLate = timeInParsed.isAtSameMomentAs(lateThreshold) || timeInParsed.isAfter(lateThreshold);
              bool isEarlyOut = timeOutParsed.isBefore(earlyOutThreshold);
              bool isOvertime = timeOutParsed.isAfter(overtimeThreshold);

              if (isLate) {
                remarks = "Late";
              } else {
                remarks = "Present";
              }

              if (isEarlyOut) {
                remarks = remarks == "Late" ? "Late & Early Out" : "Early Out";
              } else if (isOvertime) {
                remarks = "Overtime";
              }
            } catch (e) {
              remarks = "Invalid Time Format";
            }
          }

          fetchedData.add({
            'date': date,
            'timeIn': timeIn,
            'timeOut': timeOut,
            'remarks': remarks,
          });
        });

        fetchedData.sort((a, b) {
          DateTime dateTimeA = DateFormat('dd/MM/yyyy HH:mm').parse('${a['date']} ${a['timeIn']}');
          DateTime dateTimeB = DateFormat('dd/MM/yyyy HH:mm').parse('${b['date']} ${b['timeIn']}');
          return dateTimeB.compareTo(dateTimeA); // descending order to show the most recent first
        });

        setState(() {
          attendanceData = fetchedData;
          isLoading = false;
        });
      } else {
        setState(() {
          attendanceData = [];
          isLoading = false;
        });
      }
    }).catchError((error) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching data: $error');
    });
  }

  Future<void> _checkCooldown() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    DatabaseReference userRef = _database.child('attendance/${user.uid}');

    // 20 hours cooldown in milliseconds
    const int cooldownDuration = 20 * 60 * 60 * 1000; // 20 hours

    DatabaseEvent event = await userRef.once();
    final snapshot = event.snapshot;

    if (snapshot.exists) {
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      bool foundTimeInCooldown = false;
      bool foundTimeOutCooldown = false;

      for (var child in snapshot.children) {
        Map<dynamic, dynamic> data = child.value as Map<dynamic, dynamic>;

        if (data['date'] == DateFormat('dd/MM/yyyy').format(DateTime.now())) {
          int? lastActionTimestamp = data['timestamp'] != null ? data['timestamp'] as int : null;

          if (lastActionTimestamp != null) {
            int timeDiff = currentTimestamp - lastActionTimestamp;

            if (timeDiff < cooldownDuration) {
              if (data.containsKey('time_in') && data['time_in'] != 'N/A') {
                foundTimeInCooldown = true;
              }
              if (data.containsKey('time_out') && data['time_out'] != 'N/A') {
                foundTimeOutCooldown = true;
              }
            }
          }
        }
      }

      setState(() {
        isTimeInCooldown = foundTimeInCooldown;
        isTimeOutCooldown = foundTimeOutCooldown;
      });
    }
  }



  Future<void> _recordTime(String type) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    DatabaseReference userRef = _database.child('attendance/${user.uid}');

    // 20 hours cooldown in milliseconds
    const int cooldownDuration = 72000 * 1000; // 20 hours in milliseconds

    DatabaseEvent event = await userRef.once();
    final snapshot = event.snapshot;

    if (snapshot.exists) {
      bool canRecord = true;

      for (var child in snapshot.children) {
        Map<dynamic, dynamic> data = child.value as Map<dynamic, dynamic>;

        // Check for 'Time In' or 'Time Out' and compare cooldown
        if (data['date'] == currentDate) {
          String? lastActionTime = type == 'time_in' ? data['time_in'] : data['time_out'];
          int? lastActionTimestamp = data['timestamp'] != null ? data['timestamp'] as int : null;

          if (lastActionTime != null && lastActionTime != 'N/A' && lastActionTimestamp != null) {
            // Calculate the time difference
            int timeDiff = currentTimestamp - lastActionTimestamp;

            if (timeDiff < cooldownDuration) {
              canRecord = false; // Cooldown hasn't passed
              break;
            }
          }
        }
      }

      if (!canRecord) {
        // Show a message indicating cooldown is still active
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please wait for the cooldown period to pass.')),
        );
        return;
      }
    }

    if (type == 'time_in') {
      String recordKey = userRef.push().key!;

      await userRef.child(recordKey).set({
        'date': currentDate,
        'time_in': currentTime,
        'time_out': 'N/A',
        'timestamp': currentTimestamp, // Save the current timestamp
      });

      setState(() {
        isTimeInCooldown = true;
        Future.delayed(Duration(milliseconds: cooldownDuration), () {
          setState(() {
            isTimeInCooldown = false; // Reset after cooldown
          });
        });
      });
    } else if (type == 'time_out') {
      if (snapshot.exists) {
        for (var child in snapshot.children) {
          Map<dynamic, dynamic> data = child.value as Map<dynamic, dynamic>;

          if (data['date'] == currentDate && data['time_out'] == 'N/A') {
            await userRef.child(child.key!).update({
              'time_out': currentTime,
              'timestamp': currentTimestamp, // Save the current timestamp
            });
            break;
          }
        }
      }

      setState(() {
        isTimeOutCooldown = true;
        Future.delayed(Duration(milliseconds: cooldownDuration), () {
          setState(() {
            isTimeOutCooldown = false; // Reset after cooldown
          });
        });
      });
    }

    // After recording, fetch updated attendance data
    _fetchAttendanceData();
  }




  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    String formattedSelectedDate = selectedDate != null
        ? DateFormat('dd/MM/yyyy').format(selectedDate!)
        : 'All Dates';

    List<Map<String, String>> filteredData = selectedDate == null
        ? attendanceData
        : attendanceData
        .where((entry) => entry['date'] == DateFormat('dd/MM/yyyy').format(selectedDate!))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center( // Centering the RichText
            child: RichText(
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
            ),
          ),
          SizedBox(height: 20), // Adds spacing below the logo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Report',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                  ElevatedButton(
                    onPressed: _clearFilter,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('Clear', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          Text('Selected Date: $formattedSelectedDate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 10),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredData.isEmpty
                ? Center(
              child: Text(
                "No attendance records found.",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            )
                : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 5;
                if (constraints.maxWidth < 600) {
                  crossAxisCount = 2;
                } else if (constraints.maxWidth < 1000) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    var entry = filteredData[index];
                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${entry['date']}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            SizedBox(height: 5),
                            Text('Time In: ${entry['timeIn']}',
                                style: TextStyle(fontSize: 12)),
                            Text('Time Out: ${entry['timeOut']}',
                                style: TextStyle(fontSize: 12)),
                            Text('Remarks: ${entry['remarks']}',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: isTimeInCooldown ? null : () => _recordTime('time_in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTimeInCooldown ? Colors.grey : Colors.green,
                  foregroundColor: Colors.black,
                ),
                child: Text("Time In"),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                onPressed: isTimeOutCooldown ? null : () => _recordTime('time_out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTimeOutCooldown ? Colors.grey : Colors.red,
                  foregroundColor: Colors.black, // Set text color to black
                ),
                child: Text("Time Out"),
              ),
            ],
          ),
        ],
      ),
    );

  }
}
