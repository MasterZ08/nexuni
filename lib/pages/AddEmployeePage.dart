import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class AddEmployeePage extends StatefulWidget {
  @override
  _AddEmployeePageState createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child("users_acc");
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? selectedPosition;
  final List<String> positions = ['Admin', 'Employee'];
  List<Map<String, String>> _registeredUsers = [];

  Widget _buildUserReport() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 :
            MediaQuery.of(context).size.width < 900 ? 2 : 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: _registeredUsers.length,
          itemBuilder: (context, index) {
            return _CollapsibleUserCard(user: _registeredUsers[index]);
          },
        ),
      ),
    );
  }

  Future<void> _saveToDatabase() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;

        if (user != null) {
          setState(() {
            _registeredUsers.insert(0, {
              'first_name': _firstNameController.text.trim(),
              'middle_name': _middleNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'mobile_number': _mobileNumberController.text.trim(),
              'employee_id': _employeeIdController.text.trim(),
              'email': _emailController.text.trim(),
              'position': selectedPosition ?? 'Employee',
            });
          });

          await user.sendEmailVerification();

          String userId = user.uid;
          String node = selectedPosition == 'Admin' ? "users" : "users_acc";

          await FirebaseDatabase.instance.ref().child(node).child(userId).set({
            'first_name': _firstNameController.text.trim(),
            'middle_name': _middleNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'mobile_number': _mobileNumberController.text.trim(),
            'employee_id': _employeeIdController.text.trim(),
            'email': _emailController.text.trim(),
            'position': selectedPosition ?? 'Employee',
            'verified': false,
          });

          _clearFields();
          _showSuccessDialog();
        }
      } on FirebaseAuthException catch (e) {
        _showErrorDialog("Failed to Register: ${e.message}");
      }
    }
  }

  void _clearFields() {
    _firstNameController.clear();
    _middleNameController.clear();
    _lastNameController.clear();
    _mobileNumberController.clear();
    _employeeIdController.clear();
    _emailController.clear();
    _passwordController.clear();
    selectedPosition = null;
    setState(() {});
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text("Success"),
            ],
          ),
          content: Text("Account Registered Successfully. Verification email sent! Please verify your email before logging in."),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _formKey.currentState!.reset();
                setState(() {});
              },
              child: Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Error"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're on mobile or desktop based on width
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: isMobile ? AppBar(
        title: Center(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'NEX',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                TextSpan(
                  text: 'UNI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.grey[300],
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
      ) : null,
      body: SafeArea(
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField('First Name', _firstNameController),
                  SizedBox(height: 10),
                  _buildTextField('Middle Name', _middleNameController),
                  SizedBox(height: 10),
                  _buildTextField('Last Name', _lastNameController),
                  SizedBox(height: 10),
                  _buildTextField('Mobile No.', _mobileNumberController),
                  SizedBox(height: 10),
                  _buildTextField('Employee ID', _employeeIdController),
                  SizedBox(height: 10),
                  _buildTextField('Email', _emailController),
                  SizedBox(height: 10),
                  _buildTextField('Password', _passwordController, isPassword: true),
                  SizedBox(height: 10),
                  _buildDropdownField(),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveToDatabase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: Text(
                      'ADD ACCOUNT',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Divider(thickness: 2, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'Registered Users Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _buildUserReport(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Center aligned logo and icon
                      Container(
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            RichText(
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
                            SizedBox(height: 20),
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField('First Name', _firstNameController),
                            SizedBox(height: 10),
                            _buildTextField('Middle Name', _middleNameController),
                            SizedBox(height: 10),
                            _buildTextField('Last Name', _lastNameController),
                            SizedBox(height: 10),
                            _buildTextField('Mobile No.', _mobileNumberController),
                            SizedBox(height: 10),
                            _buildTextField('Employee ID', _employeeIdController),
                            SizedBox(height: 10),
                            _buildTextField('Email', _emailController),
                            SizedBox(height: 10),
                            _buildTextField('Password', _passwordController, isPassword: true),
                            SizedBox(height: 10),
                            _buildDropdownField(),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _saveToDatabase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              ),
                              child: Text(
                                'ADD ACCOUNT',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            VerticalDivider(thickness: 2, color: Colors.grey),
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registered Users Report',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(child: _buildUserReport()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: (label == 'Mobile No.' || label == 'Employee ID') ? TextInputType.number : TextInputType.text,
      inputFormatters: (label == 'Mobile No.' || label == 'Employee ID')
          ? [
        FilteringTextInputFormatter.digitsOnly,
        if (label == 'Mobile No.') LengthLimitingTextInputFormatter(11),
      ]
          : [],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        hintText: label == 'Mobile No.' ? '09XXXXXXXXX' : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Enter $label';
        }
        if (label == 'Mobile No.') {
          if (!RegExp(r'^09\d{9}$').hasMatch(value)) {
            return 'Enter a valid 11-digit number starting with 09';
          }
        }
        if (label == 'Email') {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value)) {
            return 'Enter a valid email address';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Position',
        border: OutlineInputBorder(),
      ),
      value: selectedPosition,
      items: positions.map((position) {
        return DropdownMenuItem(
          value: position,
          child: Text(position),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedPosition = value;
        });
      },
      validator: (value) => value == null ? 'Select Position' : null,
    );
  }
}

class _CollapsibleUserCard extends StatefulWidget {
  final Map<String, String> user;
  _CollapsibleUserCard({required this.user});

  @override
  __CollapsibleUserCardState createState() => __CollapsibleUserCardState();
}

class __CollapsibleUserCardState extends State<_CollapsibleUserCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${widget.user['first_name']} ${widget.user['last_name']}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          IconButton(
            icon: Icon(_isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.user.entries
                    .where((entry) => entry.key != 'first_name' && entry.key != 'last_name')
                    .map((entry) => Text(
                  "${entry.key.replaceAll('_', ' ').toUpperCase()}: ${entry.value}",
                  style: TextStyle(fontSize: 12),
                ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}