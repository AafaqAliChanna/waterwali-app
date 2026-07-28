import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_response.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080/api';

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
}
