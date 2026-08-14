import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';
import 'api_service.dart';

class ChatService {
  static final String _baseUrl = ApiService.baseUrl;

  Future<List<ChatMessage>> getHistory(String token, String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/chat');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw Exception('Could not load chat history.');
    }
  }
}