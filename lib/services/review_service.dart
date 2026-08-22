import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'session_manager.dart';

class ReviewService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<void> submitReview(
    String token,
    String orderId,
    int rating,
    String? comment,
  ) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/review');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else if (response.statusCode == 409) {
      throw Exception('You have already reviewed this order.');
    } else {
      throw Exception('Could not submit review. Please try again.');
    }
  }
}