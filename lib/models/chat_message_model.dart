class ChatMessage {
  final int id;
  final int orderId;
  final int senderId;
  final String message;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      orderId: json['orderId'],
      senderId: json['senderId'],
      message: json['message'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}