class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // e.g. ORDER_ACCEPTED, ORDER_DELIVERED, WALLET_TOPUP
  final String? orderId; // present when tapping should open that order
  final String createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.orderId,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? '',
      orderId: json['orderId']?.toString(),
      createdAt: json['createdAt'] ?? '',
      read: json['read'] == true,
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      orderId: orderId,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }
}