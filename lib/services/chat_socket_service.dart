import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';
import 'network_config.dart';
import 'session_manager.dart';

class ChatSocketService {
  StompClient? _client;
  bool _everConnected = false;

  static String get _wsUrl => NetworkConfig.wsUrlForRuntime;

  void connect({
    required String token,
    required String orderId,
    required void Function(ChatMessage message) onMessageReceived,
    required void Function() onConnected,
    required void Function(String error) onError,
  }) {
    _everConnected = false;
    _client = StompClient(
      config: StompConfig(
        url: '$_wsUrl?token=$token',
        onConnect: (frame) {
          _everConnected = true;
          onConnected();
          _client!.subscribe(
            destination: '/topic/order/$orderId/chat',
            callback: (frame) {
              if (frame.body != null) {
                final json = jsonDecode(frame.body!);
                onMessageReceived(ChatMessage.fromJson(json));
              }
            },
          );
        },
        onWebSocketError: (dynamic error) =>
            _handleFailure(token, onError),
        onStompError: (frame) => _handleFailure(token, onError),
        onDisconnect: (frame) {},
      ),
    );
    _client!.activate();
  }

  Future<void> _handleFailure(String token, void Function(String) onError) async {
    if (_everConnected) {
      // Already had a working connection — this is a network drop, not an
      // auth problem. Never force-logout someone mid-conversation over that.
      onError('Live chat disconnected. Pull to reload.');
      return;
    }
    final stillValid = await ApiService().isSessionValid(token);
    if (!stillValid) {
      SessionManager.onSessionExpired?.call();
      onError('Session expired. Please log in again.');
    } else {
      onError('Could not connect to chat. Check your internet connection.');
    }
  }

  void sendMessage(String orderId, String message) {
    if (_client == null || !_client!.connected) return;
    _client!.send(
      destination: '/app/chat/send',
      body: jsonEncode({'orderId': orderId, 'message': message}),
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}