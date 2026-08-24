import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class ProfileService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<UserProfile> getProfile(String token) async {
    final url = Uri.parse('$_baseUrl/users/me');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load your profile.');
    }
  }

  // ASSUMED endpoint — not built by backend yet.
  Future<UserProfile> updateEmail(String token, String email) async {
    final url = Uri.parse('$_baseUrl/users/me/email');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else if (response.statusCode == 409) {
      throw Exception('That email is already in use by another account.');
    } else {
      throw Exception('Could not update your email. Please try again.');
    }
  }
}