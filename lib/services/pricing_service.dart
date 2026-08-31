import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pricing_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class PricingService {
  static final String _baseUrl = ApiService.baseUrl;

  // ASSUMED endpoint — not built by backend yet.
  Future<TankerPricing> getTodaysPricing(String token) async {
    final url = Uri.parse('$_baseUrl/pricing');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return TankerPricing.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception("Could not load today's pricing.");
    }
  }
}