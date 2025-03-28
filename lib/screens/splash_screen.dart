import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/version_response.dart';
import '../providers/auth_provider.dart';
import '../utils/version_utils.dart';
import '../utils/dialog_utils.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startAppCheck();
  }

  void _startAppCheck() {
    _checkAppStatus().then((result) {
      if (mounted) {
        _handleAppStatusResult(result);
      }
    }).catchError((e) {
      if (mounted) {
        _handleError(e);
      }
    });
  }

  Future<Map<String, dynamic>> _checkAppStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final apiService = ApiService();
    final storageService = StorageService();
    final prefs = await SharedPreferences.getInstance(); // Buat compat sama kode lama

    try {
      final versionData = await apiService.checkVersion();
      if (versionData.maintenance) {
        return {'status': 'maintenance'};
      }
      if (compareVersions(Config.currentVersion, versionData.minVersion) < 0) {
        return {'status': 'update', 'updateUrl': versionData.updateUrl};
      }

      String? token = await storageService.getToken() ?? prefs.getString('access_token');
      if (token != null) {
        bool isValid = await apiService.validateToken(token);
        if (isValid) {
          return {'status': 'dashboard', 'token': token};
        }
      }
    } catch (e) {
      print("Check status failed: $e");
    }

    await storageService.clearAll();
    await prefs.clear(); // Buat compat
    return {'status': 'login'};
  }

  void _handleAppStatusResult(Map<String, dynamic> result) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    switch (result['status']) {
      case 'maintenance':
        showMaintenanceDialog(context);
        break;
      case 'update':
        showUpdateDialog(context, result['updateUrl'] as String, Config.currentVersion);
        break;
      case 'dashboard':
        authProvider.setToken(result['token'] as String);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
      case 'login':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        break;
    }
  }

  void _handleError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${error.toString()}")),
    );
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