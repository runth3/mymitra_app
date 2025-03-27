import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';
import 'camera_util.dart';

class ModelScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ModelScreen({required this.cameras, super.key});

  @override
  _ModelScreenState createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  CameraController? _controller;
  bool _isModelSaved = false;
  late int _selectedCameraIndex;

  @override
  void initState() {
    super.initState();
    _selectedCameraIndex = _getFrontCameraIndex();
    _checkModelExists();
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
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
    );
    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal inisialisasi kamera: $e");
    }
  }

  Future<void> _checkModelExists() async {
    final prefs = await SharedPreferences.getInstance();
    final modelData = prefs.getString('faceEmbedding');
    setState(() {
      _isModelSaved = modelData != null;
    });
    if (!_isModelSaved) {
      await _initializeCamera();
    }
  }

  Future<void> _takeModelPhoto() async {
    try {
      Vibration.vibrate(duration: 100);
      final XFile photo = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final faceDetector = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true));
      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isNotEmpty) {
        final embedding = _normalizeEmbedding(_generateEmbedding(faces.first));
        print("Debug: Model Embedding: $embedding");
        await _saveModel(embedding);
        setState(() {
          _isModelSaved = true;
        });
        Fluttertoast.showToast(msg: "Model disimpan");
        Navigator.pop(context);
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

  Future<void> _saveModel(List<double> embedding) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('faceEmbedding', embedding.join(','));
  }

  Future<void> _resetModel() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Reset"),
          content: const Text("Apakah Anda yakin ingin mereset model wajah?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('faceEmbedding');
                Navigator.pop(context);
                setState(() {
                  _isModelSaved = false;
                });
                Fluttertoast.showToast(msg: "Model telah direset");
                await _initializeCamera();
              },
              child: const Text("Reset"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _switchCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      setState(() {
        _controller = null; // Reset UI biar gak render controller lama
      });
      await Future.delayed(Duration(milliseconds: 100)); // Delay buat transisi mulus
    }
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    await _initializeCamera();
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
            child: _isModelSaved || _controller == null || !_controller!.value.isInitialized
                ? Container(
              color: Colors.black,
              child: const Center(
                child: Text(
                  "Model Sudah Direkam",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : CameraUtil.buildCameraPreview(
              controller: _controller!,
              screenWidth: screenWidth,
              cameraHeight: cameraHeight,
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
                _isModelSaved
                    ? const SizedBox(width: 56)
                    : FloatingActionButton(
                  onPressed: _takeModelPhoto,
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.camera_alt, size: 30),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
                  onPressed: _resetModel,
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