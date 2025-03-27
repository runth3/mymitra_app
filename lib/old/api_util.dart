import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiUtil {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    const String endpoint = "/auth/login";
    final url = Uri.parse("${Config.baseUrl}$endpoint");

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final tokenType = data['token_type'] as String;

        // Pisah access_token jadi id_token dan token
        final tokenParts = accessToken.split('|');
        final idToken = tokenParts[0]; // Misal "23"
        final token = tokenParts[1];   // Misal "3R58zmyQlouUOSUTs51MGyxkNgv1NG6N7cxQMzaT2d785059"

        // Simpan username, id_token, dan token ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('id_token', idToken);
        await prefs.setString('token', token);

        return {
          'success': true,
          'message': 'Login berhasil',
          'id_token': idToken,
          'token': token,
          'token_type': tokenType,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      throw Exception("Gagal terhubung ke server: $e");
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    const String endpoint = "/profile/me";
    final url = Uri.parse("${Config.baseUrl}$endpoint");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      return {
        'success': false,
        'message': 'Token tidak ditemukan, silakan login ulang',
      };
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Profil berhasil diambil',
          'data': data,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengambil profil',
        };
      }
    } catch (e) {
      throw Exception("Gagal terhubung ke server: $e");
    }
  }
}