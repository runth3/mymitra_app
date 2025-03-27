import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'camera_util.dart';
import 'attendance_screen.dart';

class FaceVerificationScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceVerificationScreen({required this.cameras, super.key});

  @override
  FaceVerificationScreenState createState() => FaceVerificationScreenState();
}

class FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  bool _isVerifying = false;
  double _opacity = 1.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late int _selectedCameraIndex;

  @override
  void initState() {
    super.initState();
    _selectedCameraIndex = _getFrontCameraIndex();
    _initializeCamera();
  }

  int _getFrontCameraIndex() {
    for (int i = 0; i < widget.cameras.length; i++) {
      if (widget.cameras[i].lensDirection == CameraLensDirection.front) {
        return i;
      }
    }
    return 0;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null; // Pastikan null biar gak bentrok
    }
    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
    );
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal inisialisasi kamera: $e");
    }
  }

  Future<void> _verifyFace() async {
    setState(() {
      _isVerifying = true;
    });
    Vibration.vibrate(duration: 100);
    final isLive = await _checkLiveness();
    if (isLive) {
      await _performVerification();
    } else {
      Fluttertoast.showToast(msg: "Liveness gagal, bukan wajah asli");
    }
    setState(() {
      _isVerifying = false;
    });
  }

  Future<bool> _checkLiveness() async {
    final List<double> eyeProbabilities = [];

    // Tahap 1: Cek kedipan (3 frame, total 1.5 detik)
    for (int i = 0; i < 3; i++) {
      setState(() {
        _opacity = _opacity == 1.0 ? 0.3 : 1.0;
      });
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.5);

      final XFile photo = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        Fluttertoast.showToast(msg: "Wajah tidak terdeteksi, pastikan cahaya cukup");
        faceDetector.close();
        continue;
      }

      final face = faces.first;
      eyeProbabilities.add(face.leftEyeOpenProbability ?? 1.0);
      eyeProbabilities.add(face.rightEyeOpenProbability ?? 1.0);
      print("Debug: Frame $i - Left Eye: ${face.leftEyeOpenProbability}, Right Eye: ${face.rightEyeOpenProbability}");
      faceDetector.close();
      await Future.delayed(Duration(milliseconds: 500));
    }

    if (eyeProbabilities.isEmpty) {
      return false;
    }

    final minProb = eyeProbabilities.reduce((a, b) => a < b ? a : b);
    final maxProb = eyeProbabilities.reduce((a, b) => a > b ? a : b);
    final isBlinking = maxProb > 0.7 && minProb < 0.5;
    print("Debug: Min Eye Prob: $minProb, Max Eye Prob: $maxProb, Is Blinking? $isBlinking");

    if (isBlinking) {
      return true; // Kedipan lolos
    }

    // Tahap 2: Fallback ke senyum (2 detik)
    Fluttertoast.showToast(msg: "Kedipan gagal, silakan senyum");
    await Future.delayed(Duration(seconds: 2));

    final XFile smilePhoto = await _controller!.takePicture();
    final smileInputImage = InputImage.fromFilePath(smilePhoto.path);
    final smileDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    final smileFaces = await smileDetector.processImage(smileInputImage);

    if (smileFaces.isEmpty) {
      Fluttertoast.showToast(msg: "Wajah tidak terdeteksi saat senyum");
      smileDetector.close();
      return false;
    }

    final smileFace = smileFaces.first;
    final smileProb = smileFace.smilingProbability ?? 0.0;
    print("Debug: Smile Probability: $smileProb");
    smileDetector.close();

    final isSmiling = smileProb > 0.7;
    return isSmiling;
  }

  Future<void> _performVerification() async {
    try {
      final XFile photo = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final faceDetector = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true));
      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isNotEmpty) {
        final newEmbedding = _normalizeEmbedding(_generateEmbedding(faces.first));
        final prefs = await SharedPreferences.getInstance();
        final storedEmbeddingStr = prefs.getString('faceEmbedding');
        final storedEmbedding = storedEmbeddingStr?.split(',').map(double.parse).toList();

        print("Debug: New Embedding: $newEmbedding");
        print("Debug: Stored Embedding: $storedEmbedding");

        if (storedEmbedding != null) {
          final similarity = _cosineSimilarity(newEmbedding, storedEmbedding);
          print("Debug: Cosine Similarity: $similarity");
          if (_isMatch(newEmbedding, storedEmbedding)) {
            Fluttertoast.showToast(msg: "Verifikasi berhasil! (Similarity: ${similarity.toStringAsFixed(6)})");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AttendanceScreen()),
            );
          } else {
            Fluttertoast.showToast(msg: "Verifikasi gagal (Similarity: ${similarity.toStringAsFixed(6)})");
          }
        } else {
          Fluttertoast.showToast(msg: "Tidak ada model tersimpan");
        }
      } else {
        Fluttertoast.showToast(msg: "Wajah tidak terdeteksi");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal: $e");
    }
  }

  List<double> _generateEmbedding(Face face) {
    final landmarks = face.landmarks.values.where((l) => l != null).toList();
    List<double> embedding = landmarks.expand((l) => [l!.position.x.toDouble(), l.position.y.toDouble()]).toList();

    if (landmarks.length >= 2) {
      for (int i = 0; i < landmarks.length - 1; i++) {
        for (int j = i + 1; j < landmarks.length; j++) {
          final dx = landmarks[i]!.position.x - landmarks[j]!.position.x;
          final dy = landmarks[i]!.position.y - landmarks[j]!.position.y;
          final distance = sqrt(dx * dx + dy * dy);
          embedding.add(distance);
        }
      }
    }
    return embedding;
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    final double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    return embedding.map((e) => e / (norm == 0 ? 1 : norm)).toList();
  }

  bool _isMatch(List<double> embedding1, List<double> embedding2) {
    final similarity = _cosineSimilarity(embedding1, embedding2);
    print("Debug: Cosine Similarity in _isMatch: $similarity");
    return similarity > 0.998;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    final dotProduct = a.asMap().entries.map((e) => e.value * b[e.key]).reduce((a, b) => a + b);
    final normA = sqrt(a.map((e) => e * e).reduce((a, b) => a + b));
    final normB = sqrt(b.map((e) => e * e).reduce((a, b) => a + b));
    return dotProduct / ((normA == 0 || normB == 0) ? 1 : (normA * normB));
  }

  Future<void> _resetVerification() async {
    setState(() {
      _isVerifying = false;
      _opacity = 1.0;
    });
    await _initializeCamera();
    Fluttertoast.showToast(msg: "Halaman verifikasi direset");
  }

  Future<void> _switchCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      setState(() {
        _controller = null; // Reset biar UI gak pake controller lama
      });
    }
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    await _initializeCamera();
    if (mounted) {
      setState(() {}); // Pastikan UI update setelah flip
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    const footerHeight = 100.0;
    final cameraHeight = screenHeight * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SizedBox(
            height: cameraHeight,
            child: _controller == null || !_controller!.value.isInitialized
                ? Container(color: Colors.black)
                : _isVerifying
                ? Stack(
              children: [
                CameraUtil.buildCameraPreview(
                  controller: _controller!,
                  screenWidth: screenWidth,
                  cameraHeight: cameraHeight,
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: _opacity,
                    duration: const Duration(milliseconds: 300),
                    child: const Text(
                      "Silakan Kedipkan Mata",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
                : Container(
              color: Colors.black,
              child: const Center(
                child: Text(
                  "Kedipkan Mata Saat Proses Verifikasi",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Container(
            height: footerHeight,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                FloatingActionButton(
                  onPressed: _isVerifying ? null : _verifyFace,
                  backgroundColor: Colors.greenAccent,
                  child: const Icon(Icons.camera_alt, size: 30),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
                  onPressed: _resetVerification,
                ),
                IconButton(
                  icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 30),
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}