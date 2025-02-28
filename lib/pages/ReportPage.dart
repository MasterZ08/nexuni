    import 'dart:html' as html;
    import 'dart:convert';
    import 'package:flutter/material.dart';
    import 'package:firebase_database/firebase_database.dart';
    import 'package:intl/intl.dart';
    import 'package:excel/excel.dart';

    class ReportPage extends StatefulWidget {
      @override
      _ReportPageState createState() => _ReportPageState();
    }

    class _ReportPageState extends State<ReportPage> {
      final DatabaseReference _database = FirebaseDatabase.instance.ref();
      List<Map<String, dynamic>> _attendanceRecords = [];
      List<Map<String, dynamic>> _filteredRecords = [];
      TextEditingController _searchController = TextEditingController();
      String? _selectedDate;
      bool _isSearchActive = false;
      bool _isLoading = true;

      @override
      void initState() {
        super.initState();
        _fetchAttendanceRecords();
      }

      Future<void> _fetchAttendanceRecords() async {
        setState(() {
          _isLoading = true;
        });

        DataSnapshot attendanceSnapshot = await _database.child('attendance').get();
        DataSnapshot usersSnapshot = await _database.child('users_acc').get();

        Map<String, dynamic> usersData = {};
        if (usersSnapshot.value != null && usersSnapshot.value is Map) {
          (usersSnapshot.value as Map).forEach((uid, userData) {
            usersData[uid] = {
              'employee_id': userData['employee_id'] ?? 'N/A',
              'name': "${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}".trim(),
            };
          });
        }

        List<Map<String, dynamic>> records = [];
        if (attendanceSnapshot.value != null && attendanceSnapshot.value is Map) {
          (attendanceSnapshot.value as Map).forEach((uid, attendanceData) {
            if (attendanceData is Map) {
              attendanceData.forEach((recordKey, record) {
                if (record is Map) {
                  String date = record['date'] ?? 'N/A';
                  String timeIn = record['time_in'] ?? 'N/A';
                  String timeOut = record['time_out'] ?? 'N/A';
                  String remarks = "Absent"; // Default as Absent

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

                  if (_selectedDate == null || date == _selectedDate) {
                    records.add({
                      'name': usersData[uid]?['name'] ?? 'Unknown',
                      'employee_id': usersData[uid]?['employee_id'] ?? 'N/A',
                      'date': date,
                      'time_in': timeIn,
                      'time_out': timeOut,
                      'remarks': remarks,
                    });
                  }
                }
              });
            }
          });
        }

        // Sorting records from newest to oldest
        records.sort((a, b) {
          DateTime dateA = DateFormat('dd/MM/yyyy').parse(a['date']);
          DateTime dateB = DateFormat('dd/MM/yyyy').parse(b['date']);
          return dateB.compareTo(dateA); // Newest first
        });

        setState(() {
          _attendanceRecords = records;
          _filteredRecords = records;
          _isLoading = false;
        });
      }

      void _filterSearchResults(String query) {
        List<Map<String, dynamic>> filteredList = _attendanceRecords.where((record) {
          return record['name'].toLowerCase().contains(query.toLowerCase()) ||
              record['employee_id'].toLowerCase().contains(query.toLowerCase());
        }).toList();

        setState(() {
          _filteredRecords = filteredList;
        });
      }

      Future<void> _exportToExcel() async {
        try {
          var excel = Excel.createExcel();

          // Work with the default sheet directly
          String defaultSheet = excel.sheets.keys.first;
          Sheet sheet = excel[defaultSheet];

          // Add headers
          sheet.appendRow(['Name', 'ID', 'Date', 'Time In', 'Time Out', 'Remarks']);

          // Add data rows
          for (var record in _filteredRecords) {
            sheet.appendRow([
              record['name'],
              record['employee_id'],
              record['date'],
              record['time_in'],
              record['time_out'],
              record['remarks']
            ]);
          }

          // Save the Excel file to a byte array
          List<int>? fileBytes = excel.encode();
          if (fileBytes != null) {
            final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
            final url = html.Url.createObjectUrlFromBlob(blob);

            final anchor = html.AnchorElement(href: url)
              ..setAttribute('download', 'Attendance_Report_${_selectedDate ?? "All"}.xlsx')
              ..click();

            html.Url.revokeObjectUrl(url);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Excel file downloaded.")),
            );
          } else {
            throw Exception("Failed to generate Excel file.");
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving file: $e")),
          );
        }
      }

      void _filterRecords() {
        String query = _searchController.text.toLowerCase();
        setState(() {
          _filteredRecords = _attendanceRecords.where((record) {
            return record['name'].toLowerCase().contains(query) ||
                record['employee_id'].toLowerCase().contains(query);
          }).toList();
        });
      }

      Future<void> _selectDate(BuildContext context) async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate != null ? DateFormat('dd/MM/yyyy').parse(_selectedDate!) : DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = DateFormat('dd/MM/yyyy').format(picked);
            _fetchAttendanceRecords();
          });
        }
      }

      void _clearDateFilter() {
        setState(() {
          _selectedDate = null;
          _fetchAttendanceRecords();
        });
      }

      // Build the responsive app bar
      // Modified _buildAppBar method to return AppBar (a PreferredSizeWidget)
      PreferredSizeWidget _buildAppBar(BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;

        return AppBar(
          automaticallyImplyLeading: false,
          title: isSmallScreen
              ? Container(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
              children: [
                SizedBox(height: 8), // Add some space from the top
                Padding(
                  padding: EdgeInsets.only(left: 95.0),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'NEX',    //mobile mode nexuni
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        TextSpan(
                          text: 'UNI',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: 100.0),
                  child: Text(
                    'Report', //mobile mode report attendance
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: 8), // Add some space at the bottom
              ],
            ),
          )
              : Row(
            // Desktop layout remains the same
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // More space on the left for 'Attendance Report'
              Padding(
                padding: EdgeInsets.only(left: 60.0), //pc mode attendance report
                child: Text(
                  'Attendance Report',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              // Centered NEXUNI with lower position
              Padding(
                padding: EdgeInsets.only(
                  top: 20.0,
                  left: MediaQuery.of(context).size.width < 600 ? 40.0 : 20.0, // Move further right on mobile
                ),
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
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Empty space to balance the layout on the right
              SizedBox(width: 160),
            ],
          ),
          actions: [
            // Search Icon with Expandable TextField
            if (_isSearchActive)
              Container(
                width: isSmallScreen ? 140 : 200,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _filterRecords(),
                  decoration: InputDecoration(
                    hintText: isSmallScreen ? "Search" : "Search Name or ID",
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close, size: isSmallScreen ? 18 : 24),
                      onPressed: () {
                        setState(() {
                          _isSearchActive = false;
                          _searchController.clear();
                          _fetchAttendanceRecords();
                        });
                      },
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(Icons.search, size: isSmallScreen ? 20 : 24),
                onPressed: () {
                  setState(() {
                    _isSearchActive = true;
                  });
                  _filterSearchResults(_searchController.text);
                },
              ),

            // Date Filter
            IconButton(
              icon: Icon(Icons.calendar_today, size: isSmallScreen ? 20 : 24),
              onPressed: () => _selectDate(context),
            ),

            // Clear Search Button - hide on very small screens
            if (!isSmallScreen || !_isSearchActive)
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: ElevatedButton(
                  onPressed: _clearDateFilter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 12,
                      vertical: isSmallScreen ? 0 : 8,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Clear",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ),
          ],
          centerTitle: isSmallScreen, // Center the title for mobile layout
          toolbarHeight: isSmallScreen ? 120 : kToolbarHeight, // Increase height for mobile
        );
      }


      // Build a responsive list view for mobile
      Widget _buildMobileListView() {
        if (_isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (_filteredRecords.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "No Data Found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: _filteredRecords.length,
          itemBuilder: (context, index) {
            final record = _filteredRecords[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              elevation: 2,
              child: ExpansionTile(
                title: Text(
                  record['name'] ?? 'Unknown',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('ID: ${record['employee_id']} - ${record['date']}'),
                childrenPadding: EdgeInsets.all(16),
                children: [
                  _buildInfoRow('Time In', record['time_in'] ?? 'N/A'),
                  _buildInfoRow('Time Out', record['time_out'] ?? 'N/A'),
                  _buildInfoRow(
                    'Remarks',
                    record['remarks'] ?? 'N/A',
                    textColor: _getRemarkColor(record['remarks'] ?? ''),
                  ),
                ],
              ),
            );
          },
        );
      }

      // Helper for mobile list items
      Widget _buildInfoRow(String label, String value, {Color? textColor}) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$label:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                value,
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        );
      }

      // Get color based on remarks
      Color _getRemarkColor(String remark) {
        if (remark.contains('Late')) return Colors.orange;
        if (remark == 'Present') return Colors.green;
        if (remark == 'Absent') return Colors.red;
        if (remark == 'Overtime') return Colors.blue;
        if (remark.contains('Early Out')) return Colors.deepOrange;
        return Colors.black;
      }

      // Build the data table for larger screens
      Widget _buildDataTable(BoxConstraints constraints) {
        if (_isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (_filteredRecords.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "No Data Found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: MaterialStateColor.resolveWith((states) => Colors.blueGrey.shade100),
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: [
                DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Time In', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Time Out', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _filteredRecords.map((record) {
                return DataRow(
                  cells: [
                    DataCell(Text(record['name'] ?? '')),
                    DataCell(Text(record['employee_id'] ?? '')),
                    DataCell(Text(record['date'] ?? '')),
                    DataCell(Text(record['time_in'] ?? '')),
                    DataCell(Text(record['time_out'] ?? '')),
                    DataCell(
                      Text(
                        record['remarks'] ?? 'N/A',
                        style: TextStyle(
                          color: _getRemarkColor(record['remarks'] ?? ''),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      }

      @override
      Widget build(BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isSmallScreen ? kToolbarHeight * 1.5 : kToolbarHeight),
            child: _buildAppBar(context),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0), // Increased padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Center content
              children: [
                if (_selectedDate != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Chip(
                      label: Text('Date: $_selectedDate'),
                      deleteIcon: Icon(Icons.close, size: 16),
                      onDeleted: _clearDateFilter,
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ),
                Expanded(
                  child: Center( // Center the card
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      // Make card take more space
                      margin: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 0 : 24.0,
                          vertical: 8.0
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0), // Increased padding inside card
                        child: isSmallScreen
                            ? _buildMobileListView()
                            : LayoutBuilder(builder: (context, constraints) {
                          return _buildDataTable(constraints);
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _exportToExcel,
            backgroundColor: Colors.green,
            icon: Icon(Icons.download, size: isSmallScreen ? 18 : 24),
            label: Text(
              isSmallScreen ? 'Export' : 'Export to Excel',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
            isExtended: true,
          ),
        );
      }
    }