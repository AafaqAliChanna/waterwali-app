import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'session_manager.dart';

class ComplaintService {
  static final String _baseUrl = ApiService.baseUrl;

  // ASSUMED endpoint — not built by backend yet. Confirm the real path and
  // category values with your backend partner before trusting this.
  Future<void> fileComplaint(
    String token,
    String orderId,
    String category,
    String description,
  ) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/complaints');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'category': category, 'description': description}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not submit your complaint. Please try again.');
    }
  }
}