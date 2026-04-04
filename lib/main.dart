import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'teacher_report_page.dart';
import 'student_list_page.dart';
import 'register_page.dart';
import 'dept_selection_page.dart'; 
import 'ScheduleClassPage.dart'; // ही फाईल नक्की बनवून ठेवा
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // परमिशन मागणे
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // --- ✅ इथून नवीन 'Local Notification' चं काम सुरू होतं ---
    
    // Android साठी नोटिफिकेशन चॅनेल सेट करा
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // हाच आयडी मेसेज पाठवताना वापरला पाहिजे
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    // चॅनेल तयार करा
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ३. ॲप उघडलेलं असताना (Foreground) मेसेज पकडण्यासाठी 'Listener'
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/launcher_icon', // तुमच्या ॲपचा आयकॉन
            ),
          ),
        );
      }
    });
    // --- ✅ इथपर्यंत नवीन कोड ---

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ विद्यार्थ्याने नोटिफिकेशनला परवानगी दिली आहे!');

      await FirebaseMessaging.instance.subscribeToTopic("all_students");
  print("✅ Topic Subscribed!");
    } else {
      print('❌ विद्यार्थ्याने परवानगी नाकारली आहे!');
    }

  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // SharedPreferences डेटा वाचणे
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String savedName = prefs.getString('savedName') ?? "";
  String savedId = prefs.getString('savedId') ?? "";
  String savedRole = prefs.getString('savedRole') ?? ""; 
  String savedDept = prefs.getString('savedDept') ?? "";
  String savedYear = prefs.getString('savedYear') ?? "";

  runApp(SmartAttendanceApp(
    showHome: isLoggedIn,
    studentName: savedName,
    studentId: savedId,
    userRole: savedRole,
    studentDept: savedDept,
    studentYear: savedYear, 
  ));
}

class SmartAttendanceApp extends StatelessWidget {
  final bool showHome;
  final String studentName;
  final String studentId;
  final String studentDept;
  final String studentYear;
  final String userRole;
  // ✅ १. व्हेरिएबल्स इथे (कन्स्ट्रक्टरच्या वर) असावेत
  final List<dynamic> teacherSubjects;
 SmartAttendanceApp({
    required this.showHome,
    required this.studentName,
    required this.studentDept,
    required this.studentYear,
    required this.studentId,
    required this.userRole,
    this.teacherSubjects = const [], // डिफॉल्ट रिकामी लिस्ट
  });
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      // ✅ इथे आपण चेक करतोय की होम पेजवर काय पाठवायचे
      home: showHome 
          ? HomePage(
              studentName: studentName, 
              studentId: studentId, 
              studentDept: studentDept,
              studentYear: studentYear,
              
              teacherName: userRole == "Teacher" ? studentName : "", 
              teacherDept: userRole == "Teacher" ? studentDept : "",
              userRole: userRole,
            ) 
          : LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  int _secretClickCount = 0;

  void _handleSecretClick() {
    _secretClickCount++;
    if (_secretClickCount >= 10) {
      _secretClickCount = 0;
      _showDeveloperDialog();
    }
  }

  void _showDeveloperDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Color(0xFF121212),
          child: Container(
            padding: EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.blueAccent,
                  child: Text("KT", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 20),
                Text("KT Digital Studio", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text("Innovating Digital Solutions", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                Divider(color: Colors.white10, height: 40),
                Text("Developed by", style: TextStyle(color: Colors.grey, fontSize: 14)),
                Text("Krishna Takalkar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 25),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Close", style: TextStyle(color: Colors.blueAccent)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveLoginSession(String name, String id, String role, String dept, String year) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('savedName', name);
    await prefs.setString('savedId', id);
    await prefs.setString('savedRole', role);
    await prefs.setString('savedDept', dept);
    await prefs.setString('savedYear', year);
  }

  Future<void> _handleLogin() async {
    String enteredId = _idController.text.trim();
    String enteredPass = _passController.text.trim();

    if (enteredId.isEmpty || enteredPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please enter ID and Password")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // १. विद्यार्थ्यासाठी लॉगिन तपासणे
      var studentDoc = await FirebaseFirestore.instance.collection('students').doc(enteredId).get();
      if (studentDoc.exists && studentDoc.data()!['password'] == enteredPass) {
        var data = studentDoc.data()!;
        String name = data['name'];
        String dept = data['department'] ?? "General"; 
        String year = data['year'] ?? "1st Year";

        _saveLoginSession(name, enteredId, "Student", dept, year);

        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => HomePage(
            studentName: name,
            studentId: enteredId,
            userRole: "Student",
            studentDept: dept,
            studentYear: year,
            teacherName: "",
            teacherDept: "",
          ),
        ));
        return;
      }

      // २. ॲडमिन / टीचर लॉगिन (मॅनुअल चेक)
      if (enteredId == "admin" && enteredPass == "1234") {
          _saveLoginSession("Nagesh Sir", "admin", "Teacher", "Computer", "All Years");
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => 
            DeptSelectionPage(teacherName: "Nagesh Sir", teacherId: "admin")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid ID or Password"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                colors: [Colors.blue[900]!, Colors.blue[600]!, Colors.blue[400]!],
              ),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(height: 80),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Login", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                      Text("Welcome to Smart Attendance", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(60), topRight: Radius.circular(60)),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          _inputBox("Enter ID", false, _idController),
                          _inputBox("Password", true, _passController),
                          SizedBox(height: 40),
                          _isLoading 
                            ? CircularProgressIndicator()
                            : MaterialButton(
                                onPressed: _handleLogin,
                                height: 50,
                                minWidth: double.infinity,
                                color: Colors.blue[900],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                child: Text("Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              
                          SizedBox(height: 30),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage()));
                            },
                            child: Text(
                              "New Student? Register Here",
                              style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                            ),
                          ), 
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _handleSecretClick,
              behavior: HitTestBehavior.opaque,
              child: Container(width: 80, height: 80, color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBox(String hint, bool isPassword, TextEditingController controller) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none),
      ),
    );
  }
}