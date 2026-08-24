import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class PasswordResetService {
  static final String _baseUrl = ApiService.baseUrl;

  // ASSUMED endpoint — not built by backend yet. Needs real SMS delivery on
  // the backend, which doesn't exist in this project currently.
  Future<void> requestOtp(String phone) async {
    final url = Uri.parse('$_baseUrl/auth/forgot-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not send verification code. Please try again.');
    }
  }

  // ASSUMED endpoint.
  Future<void> resetPassword(String phone, String otp, String newPassword) async {
    final url = Uri.parse('$_baseUrl/auth/reset-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp, 'newPassword': newPassword}),
    );
    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400) {
      throw Exception('Incorrect or expired code. Please try again.');
    } else {
      throw Exception('Could not reset password. Please try again.');
    }
  }
}