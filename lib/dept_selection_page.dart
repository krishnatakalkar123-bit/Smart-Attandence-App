import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart'; 

class DeptSelectionPage extends StatefulWidget {
  final String teacherName;
  final String teacherId;

  DeptSelectionPage({required this.teacherName, required this.teacherId});

  @override
  _DeptSelectionPageState createState() => _DeptSelectionPageState();
}

class _DeptSelectionPageState extends State<DeptSelectionPage> {
  String? selectedDept;
  String? selectedTeacher; 
  String? selectedTeacherSubject; // ✅ शिक्षकाचा विषय साठवण्यासाठी
  List<String> teachersList = []; 
  bool isLoadingTeachers = false;

  // १. विभाग निवडल्यावर त्या विभागातील शिक्षकांची नावे आणणे
  void _fetchTeachers(String dept) async {
    setState(() {
      isLoadingTeachers = true;
      teachersList = [];
      selectedTeacher = null;
      selectedTeacherSubject = null;
    });

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .where('department', isEqualTo: dept)
          .get();

      setState(() {
        teachersList = snapshot.docs.map((doc) => doc.data()['name'].toString()).toList();
      });
    } catch (e) {
      _showSnackBar("शिक्षकांची यादी लोड करताना एरर आला!", Colors.red);
    } finally {
      setState(() => isLoadingTeachers = false);
    }
  }

  // ✅ २. नाव निवडल्यावर त्या शिक्षकाचा 'Subject' फायरबेसमधून मिळवणे
 void _fetchTeacherSubject(String name) async {
  try {
    var snapshot = await FirebaseFirestore.instance
        .collection('teachers')
        .where('name', isEqualTo: name)
        .where('department', isEqualTo: selectedDept) // विभाग पण चेक करा
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        // ✅ खात्री करा की तुमच्या DB मध्ये 'subject' हेच नाव आहे (Small letter मध्ये)
        selectedTeacherSubject = snapshot.docs.first.data()['subject'] ?? "विषय नाही";
      });
    } else {
      setState(() {
        selectedTeacherSubject = "सापडला नाही";
      });
    }
  } catch (e) {
    print("Error: $e");
    setState(() => selectedTeacherSubject = "Error");
  }
}

  // ३. डॅशबोर्डवर जाण्यासाठी फंक्शन
  void _goToDashboard() {
    if (selectedDept == null || selectedTeacher == null) {
      _showSnackBar("कृपया विभाग आणि तुमचे नाव निवडा! ⚠️", Colors.orange);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          studentName: selectedTeacher!, 
          studentId: widget.teacherId,
      teacherName: widget.teacherName ?? "Unknown Teacher", // जर रिकामे असेल तर "Unknown Teacher" दिसेल
teacherDept: selectedDept ?? "General",
          userRole: "Teacher",
          studentDept: selectedDept!, 
          teacherSubjects: [],
          studentYear: "3rd Year", 
          // ✅ HomePage मध्ये 'teacherSubject' नावाचा पॅरामीटर असेल तर तो पाठवा
          // teacherSubject: selectedTeacherSubject, 
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Teacher Verification"),
        backgroundColor: Colors.orange[800],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(25),
        child: Column(
          children: [
            Icon(Icons.person_search_rounded, size: 80, color: Colors.orange[800]),
            SizedBox(height: 20),
            Text("शिक्षक निवड", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("तुमचा विभाग निवडा आणि तुमचे नाव निवडून प्रवेश करा.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 40),

            // विभाग निवड
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                labelText: "Select Department",
                prefixIcon: Icon(Icons.business_rounded),
              ),
              items: ["Computer", "Civil", "Mechanical", "Electrical"]
                  .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) {
                setState(() => selectedDept = val);
                _fetchTeachers(val!); 
              },
            ),
            SizedBox(height: 20),

            // शिक्षक निवड
            DropdownButtonFormField<String>(
              value: selectedTeacher,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                labelText: isLoadingTeachers ? "Loading Teachers..." : "Select Your Name",
                prefixIcon: Icon(Icons.person),
              ),
              items: teachersList.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) {
                setState(() => selectedTeacher = val);
                _fetchTeacherSubject(val!); // ✅ नाव निवडल्यावर सब्जेक्ट ओढला जाईल
              },
            ),
            
            // ✅ विषयाची माहिती दाखवण्यासाठी (फक्त खात्रीसाठी)
            if (selectedTeacherSubject != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text("तुमचा विषय: $selectedTeacherSubject", 
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),

            SizedBox(height: 40),

            // प्रवेश बटण
            ElevatedButton(
              onPressed: _goToDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: Text(
                "डॅशबोर्ड मध्ये प्रवेश करा",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}