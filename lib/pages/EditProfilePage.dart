import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('users_acc');

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DatabaseReference userRef = _dbRef.child(user.uid);
      DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> userData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _firstNameController.text = userData['first_name'] ?? '';
          _lastNameController.text = userData['last_name'] ?? '';
          _middleNameController.text = userData['middle_name'] ?? '';
          _mobileNumberController.text = userData['mobile_number'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DatabaseReference userRef = _dbRef.child(user.uid);
      await userRef.update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'mobile_number': _mobileNumberController.text.trim(),
      });

      if (_passwordController.text.isNotEmpty) {
        await user.updatePassword(_passwordController.text.trim());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[200],
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        )
            : null,
      ),
      keyboardType: isPassword ? TextInputType.text : TextInputType.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // TOP SECTION: NEXUNI centered
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: 50, bottom: 20), // Adds space at the top
            child: Center(
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
          ),

          // MAIN CONTENT (SCROLLABLE)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 60, right: 16, top: 10, bottom: 10), // Shifted right
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align text fields properly
                children: [
                  Text('Edit Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  _isLoading
                      ? CircularProgressIndicator()
                      : Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildTextField(label: 'First Name', controller: _firstNameController),
                      SizedBox(height: 10),
                      const SizedBox(height: 12),
                      _buildTextField(label: 'Last Name', controller: _lastNameController),
                      SizedBox(height: 10),
                      const SizedBox(height: 12),
                      _buildTextField(label: 'Middle Name', controller: _middleNameController),
                      SizedBox(height: 10),
                      const SizedBox(height: 12),
                      _buildTextField(label: 'Phone Number', controller: _mobileNumberController),
                      SizedBox(height: 10),
                      const SizedBox(height: 12),
                      _buildTextField(label: 'New Password', controller: _passwordController, isPassword: true),
                      SizedBox(height: 20),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _updateUserProfile,
                        child: Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
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
