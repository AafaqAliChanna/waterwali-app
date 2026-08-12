import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'api_service.dart';

class OrderService {
  // Reuses the same base URL ApiService already defines, so there's
  // only one place to change it if the backend address ever moves.
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
      // Note: price is never sent — the server calculates it. Sending it
      // would just be ignored (or rejected), so we don't include the field.
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'tankerSize': tankerSize.apiValue,
      }),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
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
    } else {
      throw Exception('Could not load your orders.');
    }
  }

  Future<Order> getOrder(String token, int orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403) {
      throw Exception('You do not have access to this order.');
    } else {
      throw Exception('Could not load order details.');
    }
  }
}
