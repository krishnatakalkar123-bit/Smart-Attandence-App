import 'dart:io';
import 'package:image/image.dart' as img;

class FaceDetectorService {
  
  Future<FaceCheckResult> verifyFace(File profilePic, File liveSelfie) async {
    try {
      final bytes1 = await profilePic.readAsBytes();
      final bytes2 = await liveSelfie.readAsBytes();
      
      img.Image? img1 = img.decodeImage(bytes1);
      img.Image? img2 = img.decodeImage(bytes2);

      if (img1 == null || img2 == null) {
        return FaceCheckResult(isValid: false, message: "फोटो नीट दिसत नाहीये. ❌");
      }

      // १. ग्रे-स्केल आणि रिसाईज (वेगवान प्रक्रियेसाठी)
      img.Image gray1 = img.grayscale(img1);
      img.Image gray2 = img.grayscale(img2);
      
      // चेहरा ओळखण्यासाठी ४८ ऐवजी ६४ पिक्सेल वापरूया (जास्त अचूकता)
      img.Image resized1 = img.copyResize(gray1, width: 64, height: 64);
      img.Image resized2 = img.copyResize(gray2, width: 64, height: 64);

      double totalDiff = 0;
      for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
          num p1 = resized1.getPixel(x, y).r;
          num p2 = resized2.getPixel(x, y).r;
          totalDiff += (p1 - p2).abs();
        }
      }

      double avgDiff = totalDiff / (64 * 64);
      
      print("---------------------------------------");
      print("🔍 DEBUG | Face Diff Score: ${avgDiff.toStringAsFixed(2)}");
      print("---------------------------------------");

      // --- फायनल लॉजिक ---
      // ८० पेक्षा कमी म्हणजे खूप जास्त मॅचिंग. 
      // जर भिंत मॅच होत असेल, तर हा आकडा अजून कमी (उदा. ७०) करा.
      if (avgDiff < 80) { 
        return FaceCheckResult(isValid: true, message: "Face Verified! ✅");
      } else if (avgDiff > 130) {
        return FaceCheckResult(isValid: false, message: "हा फोटो पूर्णपणे वेगळा आहे! ❌");
      } else {
        return FaceCheckResult(isValid: false, message: "चेहरा स्पष्ट नाही किंवा मॅच होत नाही. ❌");
      }

    } catch (e) {
      return FaceCheckResult(isValid: false, message: "Error: $e");
    }
  }

  void dispose() {
    print("Service Disposed.");
  }
}

class FaceCheckResult {
  final bool isValid;
  final String message;
  FaceCheckResult({required this.isValid, required this.message});
}