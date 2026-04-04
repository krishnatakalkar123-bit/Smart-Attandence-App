import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleClassPage extends StatefulWidget {
  final String teacherName;
  final String teacherDept;
  final List<dynamic> teacherSubjects;

  ScheduleClassPage({
    required this.teacherName,
    required this.teacherDept,
    required this.teacherSubjects,
  });

  @override
  _ScheduleClassPageState createState() => _ScheduleClassPageState();
}

class _ScheduleClassPageState extends State<ScheduleClassPage> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedYear;
  String? _selectedSubject;
  List<String> _finalSubjects = []; 
  bool _isLoading = true; // डेटा लोड होत आहे का हे पाहण्यासाठी

  @override
  void initState() {
    super.initState();
    _fetchSubjectsDirectly();
  }

  // ✅ डॅशबोर्डवरून लिस्ट आली नसेल तर थेट Firestore मधून विषय आणणे
  void _fetchSubjectsDirectly() async {
    try {
      // १. आधी डॅशबोर्डवरून आलेली लिस्ट चेक करा
      if (widget.teacherSubjects.isNotEmpty) {
        _finalSubjects = widget.teacherSubjects.map((e) => e.toString()).toList();
      } 
      
      // २. जर लिस्ट रिकामी असेल, तर Firestore मध्ये त्या सरांच्या नावाने विषय शोधा
      if (_finalSubjects.isEmpty) {
        var snapshot = await FirebaseFirestore.instance
            .collection('teachers')
            .where('name', isEqualTo: widget.teacherName)
            .get();

        if (snapshot.docs.isNotEmpty) {
          var data = snapshot.docs.first.data();
          // जर 'subject' फील्ड असेल (कोकरे सरांसारखं)
          if (data['subject'] != null) {
            _finalSubjects = [data['subject'].toString()];
          } 
          // जर 'teacherSubjects' फील्ड असेल
          else if (data['teacherSubjects'] != null) {
            _finalSubjects = List<String>.from(data['teacherSubjects']);
          }
        }
      }

      setState(() {
        // जर एकच विषय असेल तर तो आपोआप निवडा
        if (_finalSubjects.length == 1) {
          _selectedSubject = _finalSubjects[0];
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _sendClassUpdate() async {
    if (_selectedYear == null || _selectedSubject == null || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("कृपया सर्व माहिती भरा!")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('updates').add({
        'teacherName': widget.teacherName,
        'message': _messageController.text.trim(),
        'department': widget.teacherDept,
        'targetYear': _selectedYear,
        'subject': _selectedSubject,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("विद्यार्थ्यांना मेसेज पाठवला गेला! ✅"), backgroundColor: Colors.green),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("एरर: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Schedule Class"), backgroundColor: Colors.purple),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) // डेटा येईपर्यंत लोडिंग दाखवा
        : SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // १. Year Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: "Select Year", border: OutlineInputBorder()),
                  items: ["1st Year", "2nd Year", "3rd Year"].map((year) => 
                    DropdownMenuItem(value: year, child: Text(year))).toList(),
                  onChanged: (val) => setState(() => _selectedYear = val),
                ),
                
                SizedBox(height: 20),

                // २. Dynamic Subject Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Select Subject", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book, color: Colors.purple),
                  ),
                  value: _selectedSubject,
                  items: _finalSubjects.isEmpty 
                    ? [DropdownMenuItem(value: null, child: Text("No Subjects Assigned"))]
                    : _finalSubjects.map((sub) => 
                        DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                  onChanged: (val) => setState(() => _selectedSubject = val),
                ),

                SizedBox(height: 20),

                // ३. Message Input
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: "मेसेज टाका",
                    hintText: "उदा. आजचा क्लास ११ वाजता होईल.",
                    border: OutlineInputBorder(),
                  ),
                ),

                SizedBox(height: 30),

                // ४. Send Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _sendClassUpdate,
                    icon: Icon(Icons.send),
                    label: Text("SEND UPDATE TO STUDENTS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                  ),
                )
              ],
            ),
          ),
    );
  }
}