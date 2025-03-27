import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'old/model_screen.dart';
import 'old/verification_screen.dart';
import 'old/location_check_screen.dart';
import 'old/login_screen.dart';
import 'old/theme.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ThemeData theme = AppTheme.baseTheme;
        if (darkDynamic != null) {
          theme = theme.copyWith(
            colorScheme: darkDynamic,
          );
          print("Debug: Using dynamic color - ${darkDynamic.primary}");
        } else {
          print("Debug: Using fallback static theme");
        }

        return MaterialApp(
          title: 'Face Recognition App',
          theme: theme,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("Debug: HomeScreen Primary Color - ${Theme.of(context).primaryColor}");
    return Scaffold(
      appBar: AppBar(title: const Text("Face Recognition")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModelScreen(cameras: cameras),
                  ),
                );
              },
              child: const Text("Lihat Model"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaceVerificationScreen(cameras: cameras),
                  ),
                );
              },
              child: const Text("Ke Halaman Verifikasi"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationCheckScreen(),
                  ),
                );
              },
              child: const Text("Cek Lokasi"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}