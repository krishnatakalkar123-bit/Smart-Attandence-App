import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // ✅ ही ओळ टाका, एरर लगेच जाईल!
import 'package:http/http.dart' as http;

class MessageSection extends StatefulWidget {
  final String studentDept;
  final String studentYear;

  MessageSection({required this.studentDept, required this.studentYear});

  @override
  _MessageSectionState createState() => _MessageSectionState();
}

class _MessageSectionState extends State<MessageSection> {
  String selectedTeacher = "All";
  String selectedSubject = "All";

  // मास्टर डेटा साठवण्यासाठी लिस्ट
  List<String> allTeachers = ["All"];
  List<String> allSubjects = ["All"];
  bool isMasterDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  // ✅ १. डेटाबेसमधून खरे शिक्षक आणि विषय लोड करणे
  Future<void> _loadMasterData() async {
    try {
      // खऱ्या शिक्षकांची यादी (teachers collection मधून)
      var teacherSnap = await FirebaseFirestore.instance
          .collection('teachers')
          .where('department', isEqualTo: widget.studentDept)
          .get();
      
      // सर्व विषयांची यादी (subjectName collection मधून)
      var subjectSnap = await FirebaseFirestore.instance
          .collection('subjectName')
          .where('department', isEqualTo: widget.studentDept)
          .get();

      setState(() {
        for (var doc in teacherSnap.docs) {
          // तुमच्याकडे 'name' फील्ड असेल तर ती वापरा
          allTeachers.add(doc.data()['name'] ?? doc.data()['teacherName']);
        }
        for (var doc in subjectSnap.docs) {
          // तुमच्याकडे 'subjectName' फील्ड असेल तर ती वापरा
          allSubjects.add(doc.data()['subjectName'] ?? doc.data()['subject']);
        }
        isMasterDataLoading = false;
      });
    } catch (e) {
      print("Error loading master data: $e");
      setState(() => isMasterDataLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Class Updates", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
      ),
      body: isMasterDataLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ २. फिल्टर बार (आता यात फक्त खरे शिक्षक आणि सर्व विषय दिसतील)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      _buildFilterDropdown("Teacher", allTeachers, selectedTeacher, (val) {
                        setState(() { selectedTeacher = val!; });
                      }),
                      SizedBox(width: 10),
                      _buildFilterDropdown("Subject", allSubjects, selectedSubject, (val) {
                        setState(() { selectedSubject = val!; });
                      }),
                    ],
                  ),
                ),

                // ✅ ३. मेसेज लिस्ट (StreamBuilder)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('updates')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                      // विद्यार्थ्याच्या क्लासनुसार आणि फिल्टरनुसार डेटा गाळून घेणे
                      var filteredDocs = snapshot.data!.docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        bool classMatch = data['department'] == widget.studentDept && 
                                          data['targetYear'] == widget.studentYear;
                        bool teacherMatch = selectedTeacher == "All" || data['teacherName'] == selectedTeacher;
                        bool subjectMatch = selectedSubject == "All" || data['subject'] == selectedSubject;
                        return classMatch && teacherMatch && subjectMatch;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Center(child: Text("कोणतेही अपडेट्स नाहीत."));
                      }

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          var data = filteredDocs[index].data() as Map<String, dynamic>;
                          return _buildMessageCard(data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // --- ड्रॉपडाऊन डिझाइन ---
  Widget _buildFilterDropdown(String label, List<String> items, String currentVal, Function(String?) onChanged) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(currentVal) ? currentVal : "All",
            isExpanded: true,
            icon: Icon(Icons.filter_alt_outlined, size: 18, color: Colors.blue[900]),
            items: items.map((val) => DropdownMenuItem(
              value: val,
              child: Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // --- मेसेज कार्ड डिझाइन ---
  Widget _buildMessageCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[900],
          child: Icon(Icons.campaign, color: Colors.white, size: 20),
        ),
        title: Text(data['message'] ?? "", style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("By: ${data['teacherName']} | Sub: ${data['subject']}"),
      ),
    );
  }
  // हा पूर्ण तुकडा कॉपी करून तुझ्या फाईलमध्ये खाली पेस्ट कर
Future<void> sendNotificationToStudents(String title, String body, String dept, String year) async {
  try {
    String topic = "${dept}_$year".replaceAll(' ', '_');

    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        // ✅ तुझी 'Don't restrict' केलेली की आता इथे काम करेल
        'Authorization': 'key=AIzaSyB3rbwBJcSCzFghMwldEFUzWn-XFRijdIo', 
      },
      body: jsonEncode({
        'to': '/topics/$topic',
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': 'message',
        },
      }),
    );

    if (response.statusCode == 200) {
      print("✅ यश आलं! नोटिफिकेशन गेलं: ${response.body}");
    } else {
      print("❌ एरर आला: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    print("❌ नेटवर्क एरर: $e");
  }
}
}