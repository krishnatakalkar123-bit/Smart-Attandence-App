import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// PDF सर्विस इंपोर्ट करायला विसरू नकोस
// import 'package:your_app_name/attendance_report_service.dart'; 

class TeacherReportPage extends StatelessWidget {
  final String teacherName;
  final String selectedDept;
  final String selectedYear;

  TeacherReportPage({
    required this.teacherName, 
    required this.selectedDept, 
    required this.selectedYear, 
  });

  @override
  Widget build(BuildContext context) {
    // आपण डेटा इथून पास करणार आहोत, त्यामुळे आपण 'filteredDocs' ला ऍक्सेस करू शकू अशा पद्धतीने डिझाइन करू
    return Scaffold(
      appBar: AppBar(
        title: Text("$selectedDept - $selectedYear"), 
        backgroundColor: Colors.green[800],
      ),
      body: _buildAttendanceList(context), 
    );
  }

  Widget _buildAttendanceList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('department', isEqualTo: selectedDept)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("काहीतरी चूक झाली आहे."));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("$selectedDept साठी कोणताही डेटा नाही."));
        }

        // निवडलेल्या वर्षाचा डेटा फिल्टर करा
        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String dbYear = (data['year'] ?? "").toString().trim().toLowerCase();
          String targetYear = selectedYear.trim().toLowerCase();
          return dbYear == targetYear;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(child: Text("$selectedYear साठी हजेरी उपलब्ध नाही."));
        }

        // --- PDF साठी डेटा तयार करणे ---
        List<Map<String, dynamic>> pdfData = filteredDocs.map((doc) {
          return doc.data() as Map<String, dynamic>;
        }).toList();

        return Scaffold(
          // इथे आपण Floating Button लावले आहे जे फक्त डेटा असेल तरच दिसेल
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // आजची तारीख मिळवण्यासाठी
              String todayDate = DateTime.now().toString().split(' ')[0];
              
              // आपली PDF सर्विस कॉल करा
              // AttendancePDFService.downloadPresentData(selectedDept, todayDate, pdfData);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("PDF तयार होत आहे..."), backgroundColor: Colors.green),
              );
            },
            label: Text("Download PDF"),
            icon: Icon(Icons.picture_as_pdf),
            backgroundColor: Colors.red[800],
          ),
          body: ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              var data = filteredDocs[index].data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.person, color: Colors.green[800]),
                  ),
                  title: Text(data['studentName'] ?? "Unknown", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Subject: ${data['subject'] ?? 'N/A'}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("PRESENT", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                      Text(data['year'] ?? "", style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}