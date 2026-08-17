import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_response.dart';
import 'network_config.dart';

class ApiService {
  static String get baseUrl => NetworkConfig.apiBaseUrlForRuntime;

  Future<AuthResponse> login(String phone, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonMap);
    } else {
      throw Exception('Wrong phone number or password!');
    }
  }

  Future<AuthResponse> register(
    String name,
    String phone,
    String password,
    String role,
  ) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonMap);
    } else {
      throw Exception('Could not create account. That phone number may already be registered.');
    }
  }

  Future<AuthResponse> getCurrentUser(String token) async {
    final url = Uri.parse('$baseUrl/users/me');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // /users/me returns {id, name, phone, role} — no token in the body,
      // since we're the one supplying it. We reuse AuthResponse anyway so
      // the rest of the auth flow doesn't need a second model.
      return AuthResponse(
        token: token,
        userId: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        role: json['role'] ?? '',
      );
    } else {
      throw Exception('Session expired. Please log in again.');
    }
  }
  
}
