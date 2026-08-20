import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class OrderService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<Order> placeOrder({
    required String token,
    required double latitude,
    required double longitude,
    required TankerSize tankerSize,
  }) async {
    final url = Uri.parse('$_baseUrl/orders');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'tankerSize': tankerSize.apiValue,
      }),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not place your order. Please try again.');
    }
  }

  Future<List<Order>> myOrders(String token) async {
    final url = Uri.parse('$_baseUrl/orders/mine');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load your orders.');
    }
  }

    Future<Order> getOrder(String token, String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403) {
      throw Exception('You do not have access to this order.');
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load order details.');
    }
  }

  // Only valid while the order is still PENDING — once a driver accepts,
  // cancelling stops being the customer's call to make alone.
  Future<Order> cancelOrder(String token, String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/cancel');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception('This order can no longer be cancelled — a driver may have already accepted it.');
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not cancel order. Please try again.');
    }
  }
}