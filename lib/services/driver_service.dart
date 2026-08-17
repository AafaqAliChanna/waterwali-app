import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class DriverService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<bool> goOnline(String token) async {
    final url = Uri.parse('$_baseUrl/driver/online');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['isOnline'] ?? true;
    } else if (response.statusCode == 403) {
      throw Exception(
          'Cannot go online — your wallet balance is below PKR 200, or your account is suspended.');
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not go online. Please try again.');
    }
  }

  Future<bool> goOffline(String token) async {
    final url = Uri.parse('$_baseUrl/driver/offline');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['isOnline'] ?? false;
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not go offline. Please try again.');
    }
  }

  Future<List<Order>> nearbyOrders(
    String token,
    double latitude,
    double longitude, {
    double radiusKm = 5,
  }) async {
    final url = Uri.parse(
        '$_baseUrl/orders/nearby?latitude=$latitude&longitude=$longitude&radiusKm=$radiusKm');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('Only drivers can view nearby orders.');
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load nearby orders.');
    }
  }

  Future<Order> acceptOrder(String token, String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/accept');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception('Too late — another driver already accepted this order.');
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not accept order. Please try again.');
    }
  }

  Future<List<Order>> myOrders(String token) async {
    final url = Uri.parse('$_baseUrl/orders/driver-mine');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load your deliveries.');
    }
  }

  Future<Order> completeOrder(String token, String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/complete');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not mark order as delivered. Please try again.');
    }
  }
}