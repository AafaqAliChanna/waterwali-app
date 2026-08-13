import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/auth_response.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      // Running in Chrome/web -- talks straight to your laptop's localhost.
      return 'http://localhost:8080/api';
    } else if (Platform.isAndroid) {
      // Android EMULATOR only -- 10.0.2.2 is the emulator's special alias
      // for "my computer's localhost." A real Android phone needs your
      // computer's actual LAN IP instead.
      return 'http://10.0.2.2:8080/api';
    } else {
      // iOS simulator, desktop, etc. -- these can reach localhost directly.
      return 'http://localhost:8080/api';
    }
  }

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
}
