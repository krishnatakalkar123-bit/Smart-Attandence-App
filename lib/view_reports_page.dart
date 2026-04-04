import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewReportsPage extends StatefulWidget {
  final String teacherDept;
  final String teacherName; // ✅ हे नाव फिल्टरसाठी वापरणार

  ViewReportsPage({required this.teacherDept, required this.teacherName});

  @override
  _ViewReportsPageState createState() => _ViewReportsPageState();
}

class _ViewReportsPageState extends State<ViewReportsPage> {
  int currentCount = 0;
  int currentStart = 1;
  String selectedYear = '3rd Year';
  late String selectedDept;
  DateTime selectedDate = DateTime.now();
  List<String> years = ['1st Year', '2nd Year', '3rd Year'];

  final TextEditingController _countController = TextEditingController();
  final TextEditingController _startController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedDept = widget.teacherDept.trim();
    _fetchFixConfig();
  }

  Future<void> _fetchFixConfig() async {
    var doc = await FirebaseFirestore.instance
        .collection('class_configs')
        .doc("${selectedDept}_$selectedYear")
        .get();

    if (doc.exists) {
      setState(() {
        currentCount = doc.data()?['total'] ?? 0;
        currentStart = doc.data()?['start'] ?? 1;
      });
    } else {
      setState(() { currentCount = 0; });
    }
  }

  Future<void> _saveFixConfig() async {
    int count = int.tryParse(_countController.text) ?? 0;
    int start = int.tryParse(_startController.text) ?? 1;
    if (count > 0) {
      await FirebaseFirestore.instance
          .collection('class_configs')
          .doc("${selectedDept}_$selectedYear")
          .set({'total': count, 'start': start});
      _fetchFixConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.teacherName} - Reports"), // सरांचे नाव टायटलमध्ये
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTopFilter(),
          if (currentCount == 0) _buildConfigInput(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .doc(selectedDept)
                  .collection(selectedYear)
                  .doc(formattedDate)
                  .collection('records')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                // ✅ मुख्य बदल: शिक्षक फिल्टर लॉजिक
               // ४. हजर मुलांचा मॅप (rollNo नुसार)
Map<String, dynamic> presentMap = {};
if (snapshot.hasData) {
  for (var doc in snapshot.data!.docs) {
    var data = doc.data() as Map<String, dynamic>;
    
    // ✅ १. सर्वात महत्त्वाचे: शिक्षक फिल्टर (दोन्ही नावे lowercase मध्ये चेक करा)
    String dbTeacher = (data['teacherName'] ?? "").toString().trim().toLowerCase();
    String loginTeacher = widget.teacherName.trim().toLowerCase();

    if (dbTeacher == loginTeacher) {
      // ✅ २. रोल नंबर मधून फक्त अंक काढा (उदा. "CO301" -> "301")
      String rawRoll = (data['rollNo'] ?? data['studentId'] ?? "").toString().trim();
      String cleanId = rawRoll.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (cleanId.isNotEmpty) {
        // ✅ ३. पूर्ण खात्रीसाठी String ऐवजी int मध्ये कन्व्हर्ट करून पुन्हा String करा
        // जेणेकरून "01" आणि "1" मॅच होतील.
        String finalKey = int.parse(cleanId).toString();
        presentMap[finalKey] = data;
      }
    }
  }
}

                if (currentCount == 0) {
                  return Center(child: Text("आधी विद्यार्थ्यांची संख्या सेव्ह करा."));
                }

                return ListView.builder(
                  itemCount: currentCount,
                  itemBuilder: (context, index) {
                    String currentRoll = (currentStart + index).toString();
                    bool isPresent = presentMap.containsKey(currentRoll);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                      elevation: isPresent ? 2 : 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent ? Colors.green : Colors.grey[200],
                          child: Text(currentRoll, 
                            style: TextStyle(color: isPresent ? Colors.white : Colors.black54, fontSize: 12)),
                        ),
                        title: Text(
                          isPresent 
                            ? (presentMap[currentRoll]['studentName'] ?? "नाव नाही") 
                            : "Absent",
                          style: TextStyle(
                            fontWeight: isPresent ? FontWeight.bold : FontWeight.normal, 
                            color: isPresent ? Colors.black : Colors.grey
                          ),
                        ),
                        trailing: Text(
                          isPresent ? "PRESENT" : "ABSENT",
                          style: TextStyle(
                            color: isPresent ? Colors.green : Colors.red[300], 
                            fontWeight: FontWeight.bold, 
                            fontSize: 10
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigInput() {
    return Container(
      padding: EdgeInsets.all(15), color: Colors.orange[100],
      child: Row(
        children: [
          Expanded(child: TextField(controller: _countController, decoration: InputDecoration(labelText: "एकूण मुले", filled: true, fillColor: Colors.white), keyboardType: TextInputType.number)),
          SizedBox(width: 10),
          Expanded(child: TextField(controller: _startController, decoration: InputDecoration(labelText: "स्टार्ट रोल", filled: true, fillColor: Colors.white), keyboardType: TextInputType.number)),
          IconButton(icon: Icon(Icons.check_circle, color: Colors.green, size: 35), onPressed: _saveFixConfig)
        ],
      ),
    );
  }

Widget _buildTopFilter() {
  return Container(
    padding: EdgeInsets.all(12), 
    color: Colors.orange[50],
    child: Row(
      children: [
        Expanded(child: DropdownButton<String>(
          value: selectedYear, isExpanded: true,
          items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) { setState(() => selectedYear = v!); _fetchFixConfig(); },
        )),
        SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context), 
            child: Container(
              padding: EdgeInsets.all(10), 
              // ❌ इथे बाहेर 'color: Colors.white,' असं असेल तर ते काढून टाक.
              decoration: BoxDecoration(
                color: Colors.white, // ✅ कलर नेहमी इथे decoration च्या आतच असावा!
                border: Border.all(color: Colors.grey[300]!), 
                borderRadius: BorderRadius.circular(5)
              ), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Text(DateFormat('dd/MM/yyyy').format(selectedDate)), 
                  Icon(Icons.calendar_today, size: 16, color: Colors.orange[800])
                ]
              )
            )
          )
        ),
      ],
    ),
  );
}
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (picked != null) setState(() => selectedDate = picked);
  }
}