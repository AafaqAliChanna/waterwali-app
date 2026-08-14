import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_message_model.dart';
import 'network_config.dart';

class ChatSocketService {
  StompClient? _client;

  static String get _wsUrl => NetworkConfig.wsUrlForRuntime;

  void connect({
    required String token,
    required String orderId,
    required void Function(ChatMessage message) onMessageReceived,
    required void Function() onConnected,
    required void Function(String error) onError,
  }) {
    _client = StompClient(
      config: StompConfig(
        url: '$_wsUrl?token=$token',
        onConnect: (frame) {
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
        onWebSocketError: (dynamic error) => onError(error.toString()),
        onStompError: (frame) => onError(frame.body ?? 'Chat connection error'),
        onDisconnect: (frame) {},
      ),
    );
    _client!.activate();
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