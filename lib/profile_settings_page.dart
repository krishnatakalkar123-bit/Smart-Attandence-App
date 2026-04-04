import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettingsPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  ProfileSettingsPage({required this.studentId, required this.studentName});

  @override
  _ProfileSettingsPageState createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  File? _image;
  final picker = ImagePicker();
  String? _base64Photo; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfilePhoto();
  }

  Future<void> _loadCurrentProfilePhoto() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .get();
      
      if (doc.exists && doc.data() != null) {
        setState(() {
          _base64Photo = (doc.data() as Map<String, dynamic>)['profilePic'];
        });
      }
    } catch (e) {
      _showSnackBar("माहिती लोड करताना एरर आला!", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future _getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);
      setState(() {
        _image = imageFile;
        _base64Photo = base64String;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_base64Photo == null) {
      _showSnackBar("कृपया आधी फोटो निवडा!", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .update({'profilePic': _base64Photo});

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedProfilePic', _base64Photo!);

      _showSnackBar("प्रोफाईल यशस्वीरित्या अपडेट झाली✅", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar("डेटाबेस एरर: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Settings"),
        backgroundColor: Colors.blue[900],
        elevation: 0,
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // --- PROFILE PHOTO SECTION ---
                  GestureDetector(
                    onTap: _getImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _base64Photo != null 
                              ? MemoryImage(base64Decode(_base64Photo!))
                              : null,
                          child: _base64Photo == null
                              ? Icon(Icons.person, size: 70, color: Colors.grey[800])
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: Colors.blue[900],
                            radius: 18,
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(widget.studentName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 25),

                  _buildSectionContainer("About Student", [
                    _buildInfoRow("Name:", widget.studentName),
                    _buildInfoRow("Student ID:", widget.studentId),
                  ]),

                  SizedBox(height: 15),

                  _buildExpandableSection(
                    title: "About Smart Attendance",
                    icon: Icons.info_outline,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Smart Attendance with Face Recognition हे एक आधुनिक हजेरी यंत्रणा आहे. AI तंत्रज्ञानाचा वापर करून ही सिस्टीम विद्यार्थ्याचा चेहरा ओळखते आणि अचूक हजेरी नोंदवते.",
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                        ),
                      ),
                      _buildFeatureRow(Icons.face_retouching_natural, "AI Face Recognition"),
                      _buildFeatureRow(Icons.security, "Fraud-proof Attendance"),
                    ],
                  ),

                  SizedBox(height: 15),

                  // --- ३. CONTACT TEAM (Updated with Phone and Insta) ---
                  _buildExpandableSection(
                    title: "Contact Development Team",
                    icon: Icons.support_agent,
                    children: [
                      _buildTeamRow("Aditya Shinde", "Lead App Developer", "adi_shinde__108k", "8799923930"),
                      _buildTeamRow("Nagesh Sorgekar", "Senior Backend Engineer", "nagesh__patil.o7", "9923102808"),
                      _buildTeamRow("Jivan Sudke", "UI/UX Designer", "jivansudke", "9325842417"),
                      _buildTeamRow("Bhagwan Waghmare", "QA & Technical Support", "bhagwan._.01", "9021914942"),
                    ],
                  ),

                  SizedBox(height: 40),

                  MaterialButton(
                    onPressed: _saveProfile,
                    height: 55,
                    minWidth: double.infinity,
                    color: Colors.blue[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildExpandableSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.blue[900]),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
        iconColor: Colors.blue[900],
        collapsedIconColor: Colors.grey,
        shape: Border.all(color: Colors.transparent),
        childrenPadding: EdgeInsets.only(left: 15, right: 15, bottom: 15),
        children: children,
      ),
    );
  }

  Widget _buildSectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue[900])),
          Divider(height: 25),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // टीम मेंबर्ससाठी नवीन डिझाइन (Instagram आणि Call बटणासह)
// टीम मेंबर्ससाठी सुटसुटीत आणि क्लिकेबल डिझाइन
// टीम मेंबर्ससाठी सुटसुटीत आणि क्लिकेबल डिझाइन (FIXED INSTA LINK)
  Widget _buildTeamRow(String name, String post, String instaId, String phone) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, color: Colors.blue[900]),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(post, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  SizedBox(height: 6),
                  // --- INSTAGRAM ID (आता नक्की उघडेल) ---
                  GestureDetector(
                    onTap: () async {
                      // १. आधी Instagram App मध्ये उघडण्याचा प्रयत्न करा (Deep Link)
                      var url = "instagram://user?username=$instaId";
                      // २. जर App नसेल तर Browser मध्ये उघडण्यासाठी लिंक
                      var fallbackUrl = "https://www.instagram.com/$instaId/";
                      
                      try {
                        bool launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        if (!launched) {
                          await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalNonBrowserApplication);
                        }
                      } catch (e) {
                        // काहीही न चालल्यास साध्या ब्राउझरमध्ये उघडा
                        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.platformDefault);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        "@$instaId", 
                        style: TextStyle(fontSize: 12, color: Colors.pink[700], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- CALL BUTTON ---
            IconButton(
              icon: Icon(Icons.phone_forwarded, color: Colors.green[700]),
              onPressed: () async {
                final Uri telUri = Uri(scheme: 'tel', path: phone);
                await launchUrl(telUri);
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[900]),
          SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}