import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentListPage extends StatelessWidget {
  final String? filterDept; 

  StudentListPage({this.filterDept});

  @override
  Widget build(BuildContext context) {
    // जर filterDept नसेल तर 'All Students' दाखवा
    String displayTitle = (filterDept == null || filterDept!.isEmpty) 
        ? "All Students" 
        : "$filterDept Students";

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
        backgroundColor: Colors.blue[900],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // जर विभाग नसेल तर सरळ सर्व डेटा आणा
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("कोणताही डेटा सापडला नाही!"));
          }

          // डेटा फिल्टरिंग लॉजिक (Case Insensitive)
          var students = snapshot.data!.docs.where((doc) {
            if (filterDept == null || filterDept!.isEmpty) return true;
            
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String dbDept = (data['department'] ?? "").toString().trim().toLowerCase();
            String targetDept = filterDept!.trim().toLowerCase();
            
            return dbDept == targetDept;
          }).toList();

          if (students.isEmpty) {
            return Center(child: Text("या विभागासाठी विद्यार्थी उपलब्ध नाहीत."));
          }

          return ListView.builder(
            itemCount: students.length,
            padding: EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              var data = students[index].data() as Map<String, dynamic>;
              String studentName = data['name'] ?? "No Name";

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                elevation: 1,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[900],
                    child: Text(
                      studentName.isNotEmpty ? studentName[0].toUpperCase() : "?", 
                      style: TextStyle(color: Colors.white)
                    ),
                  ),
                  title: Text(studentName, style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID: ${data['id'] ?? 'N/A'} | Dept: ${data['department'] ?? 'N/A'}"),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}