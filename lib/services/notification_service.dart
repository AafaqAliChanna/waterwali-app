import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'network_config.dart';
import 'session_manager.dart';

class NotificationService {
  final String _baseUrl = NetworkConfig.apiBaseUrlForRuntime;

  Future<List<AppNotification>> getNotifications(String token) async {
    final url = Uri.parse('$_baseUrl/notifications');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => AppNotification.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      SessionManager.onSessionExpired?.call();
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Could not load notifications.');
    }
  }

  Future<void> markAsRead(String token, String notificationId) async {
    final url = Uri.parse('$_baseUrl/notifications/$notificationId/read');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Could not update notification.');
    }
  }

  Future<void> markAllAsRead(String token) async {
    final url = Uri.parse('$_baseUrl/notifications/mark-all-read');
    final response =
        await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Could not update notifications.');
    }
  }
}