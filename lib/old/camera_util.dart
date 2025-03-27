import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraUtil {
  static Widget buildCameraPreview({
    required CameraController controller,
    required double screenWidth,
    required double cameraHeight,
    String? faceGuideAsset = 'assets/images/face.png',
  }) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: screenWidth,
        height: cameraHeight,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0), // Mirror horizontal
          child: Stack(
            children: [
              CameraPreview(controller),
              if (faceGuideAsset != null)
                Center(
                  child: Image.asset(
                    faceGuideAsset,
                    fit: BoxFit.contain,
                    width: screenWidth,
                    height: cameraHeight * 0.8, // 80% tinggi kamera
                    opacity: const AlwaysStoppedAnimation(0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}