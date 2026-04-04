import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // 👈 इथे add कर
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceDetectorService {
  Interpreter? _interpreter;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );

  FaceDetectorService() {
    _loadModel();
  }

 Future<void> _loadModel() async {
  try {
    print("Trying to load model...");

    final data = await rootBundle.load('assets/mobilefacenet.tflite');
    final bytes = data.buffer.asUint8List();

    _interpreter = await Interpreter.fromBuffer(bytes);

    print("✅ AI Model Loaded!");
  } catch (e) {
    print("❌ Model Error: $e");
  }
}

  Future<FaceCheckResult> verifyFace(File profilePic, File liveSelfie) async {
    try {
      if (_interpreter == null) await _loadModel();

      // 👉 LIVE SELFIE FACE DETECT
      final inputImage = InputImage.fromFile(liveSelfie);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceCheckResult(isValid: false, message: "चेहरा सापडला नाही! ❌");
      }

      if (faces.length != 1) {
        return FaceCheckResult(isValid: false, message: "एकच चेहरा दिसला पाहिजे!");
      }

      Face liveFace = faces.first;

      // 👉 Liveness Checks
      if (liveFace.leftEyeOpenProbability != null &&
          liveFace.leftEyeOpenProbability! < 0.4) {
        return FaceCheckResult(isValid: false, message: "डोळे उघडे ठेवा 👀");
      }

      if (liveFace.boundingBox.width < 150) {
        return FaceCheckResult(isValid: false, message: "कॅमेरा जवळ धरा 🤳");
      }

      if (liveFace.headEulerAngleZ! > 10 ||
          liveFace.headEulerAngleZ! < -10) {
        return FaceCheckResult(isValid: false, message: "चेहरा सरळ ठेवा 👤");
      }

      // 👉 PROFILE IMAGE FACE DETECT
      final profileInput = InputImage.fromFile(profilePic);
      final profileFaces = await _faceDetector.processImage(profileInput);

      if (profileFaces.isEmpty) {
        return FaceCheckResult(
            isValid: false, message: "Profile photo मध्ये चेहरा नाही!");
      }

      Face profileFace = profileFaces.first;

      // 👉 EMBEDDINGS (FACE CROP करून)
      List? e1 = await _extractEmbeddings(profilePic, profileFace);
      List? e2 = await _extractEmbeddings(liveSelfie, liveFace);

      if (e1 == null || e2 == null) {
        return FaceCheckResult(isValid: false, message: "फोटो एरर ❌");
      }

      double dist = 0;
      for (int i = 0; i < e1.length; i++) {
        dist += pow((e1[i] - e2[i]), 2);
      }
      dist = sqrt(dist);

      print("PROFILE EMB: $e1");
print("LIVE EMB: $e2");
print("DISTANCE: $dist");

      print("🔍 Face Distance: $dist");

     if (dist < 1) {
        return FaceCheckResult(
            isValid: true, message: "हजेरी लागली! ✅");
      } else {
        return FaceCheckResult(
            isValid: false, message: "Face match नाही ❌");
      }

    } catch (e) {
      return FaceCheckResult(isValid: false, message: "Error: $e");
    }
  }

  // 🔥 FACE CROP FUNCTION (MAIN FIX)
img.Image cropFace(img.Image image, Face face) {
  final rect = face.boundingBox;

  int x = (rect.left - 20).toInt().clamp(0, image.width - 1);
  int y = (rect.top - 20).toInt().clamp(0, image.height - 1);
  int w = (rect.width + 40).toInt();
  int h = (rect.height + 40).toInt();

  // width/height overflow fix
  if (x + w > image.width) w = image.width - x;
  if (y + h > image.height) h = image.height - y;

  return img.copyCrop(
    image,
    x: x,
    y: y,
    width: w,
    height: h,
  );
}
  // 🔥 UPDATED EMBEDDING FUNCTION
Future<List?> _extractEmbeddings(File imageFile, Face face) async {
  try {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    final cropped = cropFace(image, face);
    img.Image resized = img.copyResize(cropped, width: 112, height: 112);

    var input = _imageToInput(resized);

    var output = List.generate(1, (_) => List.filled(192, 0.0));

    _interpreter?.run(input, output);

    return output[0];
  } catch (e) {
    print("Embedding Error: $e");
    return null;
  }
}
List<List<List<List<double>>>> _imageToInput(img.Image image) {
  return [
    List.generate(112, (y) {
      return List.generate(112, (x) {
        var pixel = image.getPixel(x, y);
        return [
          (pixel.r - 127.5) / 128,
          (pixel.g - 127.5) / 128,
          (pixel.b - 127.5) / 128,
        ];
      });
    })
  ];
}

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
  }
}

class FaceCheckResult {
  final bool isValid;
  final String message;

  FaceCheckResult({required this.isValid, required this.message});
}