import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'network_config.dart';

class LocationUpdate {
  final String orderId;
  final double latitude;
  final double longitude;

  LocationUpdate({
    required this.orderId,
    required this.latitude,
    required this.longitude,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      orderId: json['orderId']?.toString() ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class LocationSocketService {
  StompClient? _client;

  static String get _wsUrl => NetworkConfig.wsUrlForRuntime;

  // onLocationReceived is only needed on the customer side (they subscribe).
  // The driver side connects just to send, so it's left null there.
  void connect({
    required String token,
    required String orderId,
    required void Function() onConnected,
    void Function(LocationUpdate update)? onLocationReceived,
    required void Function(String error) onError,
  }) {
    _client = StompClient(
      config: StompConfig(
        url: '$_wsUrl?token=$token',
        onConnect: (frame) {
          onConnected();
          if (onLocationReceived != null) {
            _client!.subscribe(
              destination: '/topic/order/$orderId/location',
              callback: (frame) {
                if (frame.body != null) {
                  onLocationReceived(LocationUpdate.fromJson(jsonDecode(frame.body!)));
                }
              },
            );
          }
        },
        onWebSocketError: (dynamic error) => onError(error.toString()),
        onStompError: (frame) => onError(frame.body ?? 'Location connection error'),
        onDisconnect: (frame) {},
      ),
    );
    _client!.activate();
  }

  void sendLocation(String orderId, double latitude, double longitude) {
    if (_client == null || !_client!.connected) return;
    _client!.send(
      destination: '/app/location/update',
      body: jsonEncode({
        'orderId': orderId,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}