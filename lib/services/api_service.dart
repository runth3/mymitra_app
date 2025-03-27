import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mymitra/models/version_response.dart';
import 'package:mymitra/config.dart';

class ApiService {
  Future<VersionResponse> checkVersion() async {
    final response = await http.get(Uri.parse("${Config.baseUrl}/version/check"));
    if (response.statusCode == 200) {
      return VersionResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception("Failed to check version");
  }

  Future<bool> validateToken(String token) async {
    final response = await http.get(
      Uri.parse("${Config.baseUrl}/profile/me"),
      headers: {"Authorization": token}, // Udah include "Bearer "
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "password": password}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['message'] ?? "Login failed");
  }
}