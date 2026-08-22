import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/driver_profile_model.dart';
import '../models/review_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class DriverProfileService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<DriverProfile> getDriverProfile(String token, String driverId) async {
    final url = Uri.parse('$_baseUrl/drivers/$driverId/profile');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return DriverProfile.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load driver profile.');
    }
  }

  
  Future<List<Review>> getDriverReviews(String token, String driverId) async {
    final url = Uri.parse('$_baseUrl/drivers/$driverId/reviews');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Review.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load reviews.');
    }
  }
}