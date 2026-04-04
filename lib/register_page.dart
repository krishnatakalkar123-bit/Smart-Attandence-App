import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// आपण फक्त ही एक ओळ खात्रीसाठी ठेवतोय जेणेकरून प्रोजेक्ट एरर फ्री राहील
import 'home_page.dart'; 

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _regIdController = TextEditingController();
  final TextEditingController _regPassController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String selectedYear = '1st Year'; 
  String selectedDept = 'Computer';

  List<String> years = ['1st Year', '2nd Year', '3rd Year'];
  List<String> departments = ['Computer', 'Civil', 'Mechanical'];

  // --- Firebase Registration Logic (Original - No Change) ---
  Future<void> _registerToFirebase() async {
    String id = _regIdController.text.trim();
    try {
      await FirebaseFirestore.instance.collection('students').doc(id).set({
        'name': _fullNameController.text.trim(),
        'id': id,
        'rollNo': _rollNoController.text.trim(),
        'year': selectedYear,          
        'department': selectedDept,    
        'email': _emailController.text.trim(),
        'password': _regPassController.text.trim(),
        'presentCount': 0,
        'absentCount': 0,
        'lateCount': 0,
        'role': 'Student', 
        'createdAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration Successful!"), backgroundColor: Colors.green),
        );
        // रजिस्ट्रेशन झाल्यावर युजरला परत लॉगिन स्क्रीनवर पाठवण्यासाठी
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Helper Widget: Input Field (Original) ---
  Widget _regField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        validator: (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue[900]),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // --- Helper Widget: Dropdown (Original) ---
  Widget _buildDropdown(List<String> items, String currentVal, Function(String?) onChange) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          isExpanded: true,
          items: items.map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900], 
        elevation: 0, 
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Registration", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.blue[900],
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
                ),
                child: Column(
                  children: [
                    Text("Register Student", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    CircleAvatar(
                      radius: 50, 
                      backgroundColor: Colors.white, 
                      child: Icon(Icons.person, size: 60, color: Colors.grey[400])
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _regField("Full Name", Icons.person, _fullNameController),
                    _regField("Student ID", Icons.badge, _regIdController),
                    _regField("Roll Number", Icons.numbers, _rollNoController),
                    _regField("Email ID", Icons.email, _emailController),
                    
                    Text("Select Year", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDropdown(years, selectedYear, (val) => setState(() => selectedYear = val!)),
                    
                    SizedBox(height: 15),
                    Text("Select Department", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDropdown(departments, selectedDept, (val) => setState(() => selectedDept = val!)),
                    
                    SizedBox(height: 20),
                    _regField("Create Password", Icons.lock, _regPassController, isPassword: true),
                    
                    SizedBox(height: 30),
                    MaterialButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _registerToFirebase();
                        }
                      },
                      height: 50,
                      minWidth: double.infinity,
                      color: Colors.blue[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Text("Register Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}