import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert'; // डेटा फॉरमॅटसाठी
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'dept_selection_page.dart';
import 'department_classes_page.dart';
import 'ScheduleClassPage.dart';
import 'AttendanceTimerPage.dart';
import 'view_reports_page.dart';
import 'message_page.dart';
import 'student_list_page.dart';
import 'student_attendance_page.dart';
import 'teacher_report_page.dart';
import 'profile_settings_page.dart'; 

class HomePage extends StatefulWidget { 
  final String studentName;
  final String studentId;
  final String studentDept;
  final String studentYear;
  final String teacherName;
  final String teacherDept;
  final List<dynamic> teacherSubjects;
  final String? subject;
  final String userRole;
  final String? dept;

  HomePage({
    required this.studentName, 
    required this.studentId, 
    required this.studentDept,
    required this.studentYear,
    required this.teacherName,
    required this.teacherDept,
    this.subject,
    required this.userRole,
    this.dept, 
    this.teacherSubjects = const [],
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(initialPage: 1);
  @override
  void initState() {
    super.initState();
    // ✅ विद्यार्थ्याने ॲप उघडले की तो आपोआप नोटिफिकेशनला सबस्क्राइब होईल
    if (widget.userRole == "Student") {
      _setupNotifications();
    }
  }

 void _setupNotifications() async {
  // १. आधी नोटिफिकेशनची परवानगी घ्या
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
  
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // २. टॉपिकचे नाव तयार करा (उदा. CO_Third_Year)
    // टीप: इथे स्पेलिंग आणि स्पेसची काळजी घेण्यासाठी .replaceAll वापरा
    String topicName = "${widget.studentDept}_${widget.studentYear}".replaceAll(' ', '_');

    // ३. सबस्क्राइब करा
    await FirebaseMessaging.instance.subscribeToTopic(topicName);
    
    // ✅ हे प्रिंट तुझ्या Debug Console मध्ये येतेय का तपासा
    print("✅ Student Subscribed to Topic: $topicName");
  } else {
    print("❌ Notification Permission Denied");
  }
}

  // --- LOGOUT LOGIC ---
 Future<void> _handleLogout(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("तुम्हाला खात्री आहे की तुम्हाला लॉगआउट करायचे आहे?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("नाही")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("हो", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == "Teacher" || widget.userRole == "Admin") {
      return _buildTeacherDashboard(context);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Student Portal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          IconButton(icon: Icon(Icons.logout, color: Colors.white), onPressed: () => _handleLogout(context))
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // trim() वापरलाय जेणेकरून ID मध्ये स्पेस असेल तर एरर येणार नाही
        stream: FirebaseFirestore.instance.collection('students').doc(widget.studentId.trim()).snapshots(),
        builder: (context, studentSnap) {
          if (!studentSnap.hasData || !studentSnap.data!.exists) {
            return Center(child: CircularProgressIndicator());
          }

          var userData = studentSnap.data!.data() as Map<String, dynamic>;
          String myDept = userData['department'] ?? "Not Assigned";
          String? profileUrl = userData['profilePic'];

          // ✅ बदल: डेटाबेस मधून 'presentCount' वाचणे
          int present = int.tryParse(userData['presentCount'].toString()) ?? 0;

          // ३ री स्ट्रीम: एकूण लेक्चर्स (Original logic)
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('class_configs').where('department', isEqualTo: myDept).snapshots(),
            builder: (context, configSnap) {
              
              int late = 0, totalSessions = 0, absent = 0;

              if (configSnap.hasData) {
                totalSessions = configSnap.data!.docs.length;
                // हजेरीच्या आकड्यावरून Absent मोजणे
                absent = totalSessions - present;
                if (absent < 0) absent = 0;
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSection(profileUrl),
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 25, bottom: 10),
                      child: Text("My Department", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    ),
                    _buildSingleDepartmentCard(context, myDept),
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // ✅ आता हे आकडे रिअल-टाइम दिसतील
                          _buildLiveStatusCards(present, late, absent),
                          SizedBox(height: 25),
                          // ✅ ग्राफमध्ये पण खरा आकडा दिसेल
                          _buildWorkingHoursChart(present, late, absent),
                          SizedBox(height: 25),
                          _buildScanButton(context, myDept), 
                          SizedBox(height: 25),
                          _buildListTile("View Classmates", Icons.people, Colors.green[800]!, context, myDept),
                          _buildListTile("My Attendance History", Icons.history, Colors.blue[900]!, context, null),
                          _buildListTile("Profile Settings", Icons.settings, Colors.grey[700]!, context, null),
                          _buildListTile("Class Messages & Updates", Icons.message_rounded, Colors.orange[800]!, context, null),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }

  // --- TEACHER DASHBOARD (NO CHANGES) ---
  Widget _buildTeacherDashboard(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Teacher Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(icon: Icon(Icons.logout, color: Colors.white), onPressed: () => _handleLogout(context))
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.orange[800],
            child: Row(
              children: [
                CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.school, color: Colors.orange[800])),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome, Prof. ${widget.studentName}", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Dept: ${widget.dept ?? 'Select Dept'} | ID: ${widget.studentId}", style: TextStyle(color: Colors.white70)),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _teacherActionCard(context, "Take Attendance", Icons.camera_front, Colors.orange, () => _showYearSelection()),
                  _teacherActionCard(context, "All Students", Icons.people, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentListPage()))),
                  _teacherActionCard(context, "View Reports", Icons.assessment, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewReportsPage(teacherDept: widget.studentDept, teacherName: widget.studentName)))),
                  _teacherActionCard(context, "Schedule Class", Icons.event, Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleClassPage(teacherName: widget.studentName, teacherDept: widget.studentDept, teacherSubjects: widget.teacherSubjects)));
                  }),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showYearSelection() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (btmContext) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("हजेरीसाठी वर्ष निवडा", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800])),
            SizedBox(height: 20),
            _buildYearTile("1st Year", Icons.filter_1),
            _buildYearTile("2nd Year", Icons.filter_2),
            _buildYearTile("3rd Year", Icons.filter_3),
          ],
        ),
      ),
    );
  }

  Widget _buildYearTile(String year, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange[800]),
      title: Text(year),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceTimerPage(selectedYear: year, teacherDept: widget.studentDept, teacherName: widget.studentName)));
      },
    );
  }

  // --- UPDATED UI HELPERS ---

  Widget _buildLiveStatusCards(int p, int l, int a) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        _statusCard(p.toString(), "Present", Colors.green), 
        _statusCard(l.toString(), "Late", Colors.orange), 
        _statusCard(a.toString(), "Absent", Colors.red)
      ]
    );
  }

  Widget _statusCard(String value, String label, Color color) {
    return Container(width: 100, padding: EdgeInsets.all(15), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Column(children: [Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)))]));
  }

  Widget _buildWorkingHoursChart(int p, int l, int a) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Attendance Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
        SizedBox(height: 20), 
        SizedBox(height: 150, child: BarChart(BarChartData(
          borderData: FlBorderData(show: false), 
          gridData: FlGridData(show: false), 
          barGroups: [
            _chartGroup(0, p.toDouble(), Colors.green), // Present
            _chartGroup(1, l.toDouble(), Colors.orange), // Late
            _chartGroup(2, a.toDouble(), Colors.red), // Absent
          ]
        )))
      ]),
    );
  }

  BarChartGroupData _chartGroup(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: color, width: 25, borderRadius: BorderRadius.circular(4))]);
  }

  // --- OTHER UI HELPERS (KEEPING YOUR ORIGINAL DESIGN) ---

// HomePage मधील हे Stream अपडेट कर:
Widget _buildSingleDepartmentCard(BuildContext context, String dept) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance_status')
          .where('dept', isEqualTo: dept)
          .where('year', isEqualTo: widget.studentYear)
          .where('isActive', isEqualTo: true) 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _originalDeptUI(dept);
        }

        var activeTeachers = snapshot.data!.docs;
        DateTime now = DateTime.now();

        // फक्त ज्यांचा टायमर अजून चालू आहे असेच सर दाखवा
        var liveTeachers = activeTeachers.where((doc) {
          DateTime endTime = (doc['endTime'] as Timestamp).toDate();
          return now.isBefore(endTime);
        }).toList();

        if (liveTeachers.isEmpty) return _originalDeptUI(dept);

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          height: 90,
          decoration: BoxDecoration(
            color: Colors.green[50], 
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: liveTeachers.length,
            itemBuilder: (context, index) {
              var data = liveTeachers[index].data() as Map<String, dynamic>;
              return Padding(
                padding: EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over, color: Colors.green[800], size: 30),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("LIVE ATTENDANCE", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
                        Text("Prof. ${data['teacherName']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Spacer(),
                    CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.green)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _originalDeptUI(String dept) {
    return Container(margin: EdgeInsets.symmetric(horizontal: 20), padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(15)), child: _originalDeptUIContent(dept));
  }

  Widget _originalDeptUIContent(String dept) {
    return Row(children: [Icon(Icons.laptop_chromebook, color: Colors.orange[800], size: 40), SizedBox(width: 15), Text(dept, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800])), Spacer(), Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange[400])]);
  }

  Widget _teacherActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 40, color: color), SizedBox(height: 10), Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))])));
  }

  Widget _buildProfileSection(String? profileUrl) {
    return Container(width: double.infinity, padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))), child: Row(children: [CircleAvatar(radius: 35, backgroundColor: Colors.white, backgroundImage: (profileUrl != null && profileUrl.isNotEmpty) ? NetworkImage(profileUrl) : null, child: (profileUrl == null || profileUrl.isEmpty) ? Icon(Icons.person, size: 40, color: Colors.blue[900]) : null), SizedBox(width: 20), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)), Text(widget.studentName, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text("ID: ${widget.studentId}", style: TextStyle(color: Colors.white70, fontSize: 13))])]));
  }

  Widget _buildScanButton(BuildContext context, String dept) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentAttendancePage(studentName: widget.studentName, studentId: widget.studentId, studentDept: widget.studentDept, studentYear: widget.studentYear, department: widget.studentDept, year: widget.studentYear))),
      child: Container(padding: EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[700]!]), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_front, color: Colors.white, size: 30), SizedBox(width: 15), Text("TAKE SELFIE ATTENDANCE", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))])),
    );
  }

  Widget _buildListTile(String title, IconData icon, Color color, BuildContext context, String? dept) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        if (title == "View Classmates") Navigator.push(context, MaterialPageRoute(builder: (context) => StudentListPage(filterDept: dept)));
        else if (title == "Profile Settings") Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsPage(studentId: widget.studentId, studentName: widget.studentName)));
        else if (title == "Class Messages & Updates") Navigator.push(context, MaterialPageRoute(builder: (context) => MessageSection(studentDept: widget.studentDept, studentYear: widget.studentYear)));
      },
    );
  }
}