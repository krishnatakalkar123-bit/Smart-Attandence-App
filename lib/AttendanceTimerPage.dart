import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceTimerPage extends StatefulWidget {
  final String selectedYear;
  final String teacherDept;
  final String teacherName;

  AttendanceTimerPage({
    required this.selectedYear,
    required this.teacherDept,
    required this.teacherName,
  });

  @override
  _AttendanceTimerPageState createState() => _AttendanceTimerPageState();
}

class _AttendanceTimerPageState extends State<AttendanceTimerPage> {
  // ------------------------------------------------------------------
  // ⚡ फक्त इथे मिनिटे बदला (उदा. 2, 5, 10 इ.)
  static const int attendanceDuration = 1; 
  // ------------------------------------------------------------------

  int _secondsRemaining = attendanceDuration * 60; 
  Timer? _timer;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _checkExistingTimer();
  }

  // १. बॅकग्राउंड सपोर्टसाठी आधीच सुरू असलेला टायमर तपासणे
  void _checkExistingTimer() async {
    var doc = await FirebaseFirestore.instance
        .collection('attendance_status')
        .doc("${widget.teacherDept}_${widget.selectedYear}")
        .get();

    if (doc.exists && doc['isActive'] == true) {
      DateTime endTime = (doc['endTime'] as Timestamp).toDate();
      DateTime now = DateTime.now();

      if (now.isBefore(endTime)) {
        int remaining = endTime.difference(now).inSeconds;
        setState(() {
          _secondsRemaining = remaining;
          _isTimerRunning = true;
        });
        _runLocalTimer(endTime);
      } else {
        _stopTimer();
      }
    }
  }

  // २. टायमर सुरू करणे (EndTime सह)
  void _startTimer() async {
    DateTime startTime = DateTime.now();
    // इथे attendanceDuration वापरला आहे
    DateTime endTime = startTime.add(Duration(minutes: attendanceDuration)); 

    setState(() {
      _isTimerRunning = true;
      _secondsRemaining = attendanceDuration * 60;
    });

    await FirebaseFirestore.instance
        .collection('attendance_status')
        .doc("${widget.teacherDept}_${widget.selectedYear}")
        .set({
      'isActive': true,
      'startTime': startTime,
      'endTime': endTime, 
      'teacherName': widget.teacherName,
      'year': widget.selectedYear,
      'dept': widget.teacherDept,
    });

    _runLocalTimer(endTime);
  }

  // ३. लोकल टायमर रन करणे (बॅकग्राउंडमधून आल्यावर सिंक राहण्यासाठी)
  void _runLocalTimer(DateTime endTime) {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        DateTime now = DateTime.now();
        Duration diff = endTime.difference(now);

        if (diff.inSeconds <= 0) {
          _stopTimer();
        } else {
          setState(() {
            _secondsRemaining = diff.inSeconds;
          });
        }
      }
    });
  }

  // ४. टायमर थांबवणे
  void _stopTimer() async {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
        _secondsRemaining = 0;
      });
    }

    await FirebaseFirestore.instance
        .collection('attendance_status')
        .doc("${widget.teacherDept}_${widget.selectedYear}")
        .update({'isActive': false});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return "00:00";
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.selectedYear} - Live Attendance"),
        backgroundColor: Colors.orange[800],
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Colors.orange[800]!, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Text("शिल्लक वेळ (Time Left)", style: TextStyle(color: Colors.grey)),
                  Text(
                    _formatTime(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 70,
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining < 60 ? Colors.red : Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .doc(widget.teacherDept)
                  .collection(widget.selectedYear)
                  .doc(todayDate)
                  .collection('records')
                  .where('teacherName', isEqualTo: widget.teacherName)
                  .snapshots(),
              builder: (context, snapshot) {
                int liveCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Container(
                  width: 220,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.people_alt_rounded, color: Colors.green, size: 40),
                      Text("LIVE COUNT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
                      Text(
                        "$liveCount",
                        style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                      Text("विद्यार्थी हजर", style: TextStyle(fontSize: 14, color: Colors.green[900])),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 50),

            _isTimerRunning
                ? Column(
                    children: [
                      CircularProgressIndicator(color: Colors.green),
                      SizedBox(height: 15),
                      Text("हजेरी प्रक्रिया सुरू आहे...", 
                          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: _stopTimer, 
                        child: Text("Stop Early", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _startTimer,
                    icon: Icon(Icons.play_circle_fill, size: 30),
                    label: Text("START ATTENDANCE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 5,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}