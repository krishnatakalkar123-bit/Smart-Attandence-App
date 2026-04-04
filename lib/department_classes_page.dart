import 'package:flutter/material.dart';
import 'teacher_report_page.dart';

class DepartmentClassesPage extends StatelessWidget {
  final String deptName;
  final String teacherName;

  DepartmentClassesPage({required this.deptName, required this.teacherName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$deptName Dept - Classes"), backgroundColor: Colors.orange[800]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome, $teacherName", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            _classCard(context, "1st Year", Icons.looks_one),
            _classCard(context, "2nd Year", Icons.looks_two),
            _classCard(context, "3rd Year", Icons.looks_3),
          ],
        ),
      ),
    );
  }

  Widget _classCard(BuildContext context, String year, IconData icon) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange, size: 30),
        title: Text("$year Attendance"),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => TeacherReportPage(
              teacherName: teacherName,
              selectedDept: deptName,
              selectedYear: year,
            )
          ));
        },
      ),
    );
  }
}