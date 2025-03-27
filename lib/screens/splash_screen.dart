import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/version_response.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppStatus();
  }

  Future<void> _checkAppStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final apiService = ApiService();
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final versionData = await apiService.checkVersion();
      if (versionData.maintenance) {
        _showMaintenanceDialog();
        return;
      }
      if (_compareVersions('1.0.0', versionData.minVersion) < 0) {
        _showUpdateDialog(versionData.updateUrl);
        return;
      }

      String? token = prefs.getString('access_token');
      if (token != null) {
        bool isValid = await apiService.validateToken(token);
        if (isValid) {
          authProvider.setToken(token);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        } else {
          _forceLogout(prefs);
        }
      } else {
        _forceLogout(prefs);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
      _forceLogout(prefs);
    }
  }

  int _compareVersions(String current, String min) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = min.split('.').map(int.parse).toList();
    for (int i = 0; i < minParts.length; i++) {
      if (currentParts[i] < minParts[i]) return -1;
      if (currentParts[i] > minParts[i]) return 1;
    }
    return 0;
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Pemeliharaan"),
        content: const Text("Sistem sedang dalam pemeliharaan. Silakan coba lagi nanti."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Update Diperlukan"),
        content: const Text("Versi Anda (1.0.0) usang. Update ke versi terbaru."),
        actions: [
          TextButton(
            onPressed: () async {
              await launchUrl(Uri.parse(updateUrl));
            },
            child: const Text("Update Sekarang"),
          ),
        ],
      ),
    );
  }

  void _forceLogout(SharedPreferences prefs) async {
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}