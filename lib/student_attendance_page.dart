import 'dart:io';
import 'dart:convert'; // Base64 साठी
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart'; // लोकेशनसाठी
import 'face_detector_service.dart'; 

class StudentAttendancePage extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String studentDept;
  final String studentYear; 
  final String department; 
  final String year;

  StudentAttendancePage({
    required this.studentName,
    required this.studentId,
    required this.studentDept,
    required this.studentYear, 
    required this.department, 
    required this.year,
  });

  @override
  _StudentAttendancePageState createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  String? selectedTeacher;
  String? selectedSubject;
  
  final FaceDetectorService _faceService = FaceDetectorService();
  final ImagePicker _picker = ImagePicker();

  static const double collegeLat = 19.638517; 
  static const double collegeLng = 76.691336;
  static const double allowedRadius = 500; 

  @override
  void dispose() {
    _faceService.dispose(); 
    super.dispose();
  }

  Future<bool> _isStudentInCollege() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("GPS चालू करा!", Colors.red);
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true,
        timeLimit: Duration(seconds: 20),
      );

      if (position.isMocked) {
        _showSnackBar("Fake GPS वापरू नका! ❌", Colors.red);
        return false;
      }

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        collegeLat,
        collegeLng,
      );

      return distance <= allowedRadius;
    } catch (e) {
      print("Location error: $e");
      return false;
    }
  }

  Future<void> _takeSelfieAndMarkAttendance() async {
    if (selectedTeacher == null || selectedSubject == null) {
      _showSnackBar("कृपया शिक्षक आणि विषय निवडा!", Colors.orange);
      return;
    }

    bool inCollege = await _isStudentInCollege();
    if (!inCollege) {
      _showSnackBar("तुम्ही कॉलेज कॅम्पसच्या बाहेर आहात! ❌", Colors.red);
      return;
    }

    try {
      // ✅ Debugging साठी आयडी प्रिंट करा
      print("Attandance marking for ID: ${widget.studentId.trim()}");

      var studentDocSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId.trim())
          .get();

      String? base64String = studentDocSnapshot.data()?['profilePic'];

      if (base64String == null || base64String.isEmpty) {
        _showSnackBar("तुमचा प्रोफाइल फोटो सापडला नाही ❌", Colors.red);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      File savedProfileFile = File('${directory.path}/profile_verify.jpg');
      Uint8List bytes = base64Decode(base64String);
      await savedProfileFile.writeAsBytes(bytes);

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 25,
      );

      if (photo == null) return;
      File liveSelfieFile = File(photo.path);

      FaceCheckResult result = await _faceService.verifyFace(savedProfileFile, liveSelfieFile);

      if (!result.isValid) {
        _showSnackBar(result.message, Colors.red);
        return; 
      }

      String todayDate = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      // १. हजेरीचे रेकॉर्ड साठवणे
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.studentDept.trim())
          .collection(widget.studentYear.trim())
          .doc(todayDate)
          .collection('records')
          .add({
        'studentName': widget.studentName.trim(),
        'studentId': widget.studentId.trim(),
        'department': widget.studentDept.trim(),
        'year': widget.studentYear.trim(),
        'teacherName': selectedTeacher,
        'subject': selectedSubject,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Present',
      });

      // ✅ २. 'presentCount' अपडेट - हा भाग आता एकदम सुरक्षित आहे
      int currentCount = 0;
      if (studentDocSnapshot.exists) {
        var data = studentDocSnapshot.data() as Map<String, dynamic>;
        currentCount = int.tryParse(data['presentCount'].toString()) ?? 0;
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId.trim())
          .set({
        'presentCount': currentCount + 1,
      }, SetOptions(merge: true));

      _showSnackBar("Attendance Marked Successfully ✅", Colors.green);
      
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context);
      });

    } catch (e) {
      print("Error: $e");
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    String cleanDept = widget.studentDept.trim();
    return Scaffold(
      appBar: AppBar(title: Text("Mark Attendance"), backgroundColor: Colors.blue[900]),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTeacherDropdown(cleanDept),
            SizedBox(height: 20),
            _buildSubjectDropdown(cleanDept),
            SizedBox(height: 40),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherDropdown(String dept) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
      builder: (context, teacherSnapshot) {
        if (!teacherSnapshot.hasData) return LinearProgressIndicator();

        var teachers = teacherSnapshot.data!.docs.where((doc) =>
            doc['department'].toString().toLowerCase().trim() == dept.toLowerCase()).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('attendance_status').snapshots(),
          builder: (context, statusSnapshot) {
            List<String> activeTeachers = [];
            if (statusSnapshot.hasData) {
              for (var doc in statusSnapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                if (data['isActive'] == true) {
                  activeTeachers.add(data['teacherName']);
                }
              }
            }

            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Select Teacher",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              value: selectedTeacher,
              items: teachers.map((doc) {
                String tName = doc['name'].toString();
                bool isTeacherActive = activeTeachers.contains(tName);

                return DropdownMenuItem(
                  value: tName,
                  enabled: isTeacherActive, 
                  child: Row(
                    children: [
                      Text(tName, style: TextStyle(
                        color: isTeacherActive ? Colors.black : Colors.grey,
                      )),
                      if (isTeacherActive) ...[
                        SizedBox(width: 10),
                        Icon(Icons.circle, color: Colors.green, size: 10),
                      ]
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedTeacher = val),
            );
          },
        );
      },
    );
  }

  Widget _buildSubjectDropdown(String dept) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('subjectName').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        var subjects = snapshot.data!.docs.where((doc) =>
            doc['department'].toString().toLowerCase().trim() == dept.toLowerCase()).toList();
        if (subjects.isEmpty) return Text("विषय सापडले नाहीत.", style: TextStyle(color: Colors.red));
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: "Select Subject", border: OutlineInputBorder(), prefixIcon: Icon(Icons.book)),
          value: selectedSubject,
          items: subjects.map((doc) => DropdownMenuItem(value: doc['name'].toString(), child: Text(doc['name']))).toList(),
          onChanged: (val) => setState(() => selectedSubject = val),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    bool isReady = selectedTeacher != null && selectedSubject != null;
    return ElevatedButton.icon(
      icon: Icon(Icons.camera_front, color: Colors.white),
      label: Text("Verify Face & Submit", style: TextStyle(color: Colors.white)),
      onPressed: isReady ? _takeSelfieAndMarkAttendance : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isReady ? Colors.blue[900] : Colors.grey,
        minimumSize: Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}