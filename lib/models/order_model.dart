// The four tanker sizes the backend accepts. We keep this as an enum (instead
// of raw strings everywhere) so the UI can't accidentally send a typo'd value.
enum TankerSize { size1000L, size2000L, size3000L, size5000L }

extension TankerSizeX on TankerSize {
  // Exact string the backend expects in the POST /api/orders body.
  String get apiValue {
    switch (this) {
      case TankerSize.size1000L:
        return 'SIZE_1000L';
      case TankerSize.size2000L:
        return 'SIZE_2000L';
      case TankerSize.size3000L:
        return 'SIZE_3000L';
      case TankerSize.size5000L:
        return 'SIZE_5000L';
    }
  }

    // Human-friendly label shown on the picker.
  String get label {
    switch (this) {
      case TankerSize.size1000L:
        return '1000 Litres';
      case TankerSize.size2000L:
        return '2000 Litres';
      case TankerSize.size3000L:
        return '3000 Litres';
      case TankerSize.size5000L:
        return '5000 Litres';
    }
  }

  // Rough US-gallon equivalent (1 litre ≈ 0.264172 gallons), for users more
  // familiar with gallons than litres.
  int get gallons {
    switch (this) {
      case TankerSize.size1000L:
        return 264;
      case TankerSize.size2000L:
        return 528;
      case TankerSize.size3000L:
        return 793;
      case TankerSize.size5000L:
        return 1321;
    }
  }
}

class Order {
  final String id;
  final String customerId; // CHANGED: backend sends UUID strings for user IDs
  final String? driverId;
  final double latitude;
  final double longitude;
  final String tankerSize;
  final double price;
  final String status;
  final String createdAt;
  // Null until the order is ACCEPTED or later — the backend hides these on
  // purpose for PENDING orders, so the UI must handle null here, not assume
  // they're always present.
    final String? customerPhone;
  final String? driverPhone;
  final String? confirmedAt;
  final String? cancelDeadline;

  Order({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.latitude,
    required this.longitude,
    required this.tankerSize,
    required this.price,
    required this.status,
    required this.createdAt,
    this.customerPhone,
    this.driverPhone,
    this.confirmedAt,
    this.cancelDeadline,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      driverId: json['driverId']?.toString(),
      // Cast via num first — the JSON value can arrive as int or double
      // depending on the value, and .toDouble() only exists on num.
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      tankerSize: json['tankerSize'] ?? '',
      price: (json['price'] as num).toDouble(),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] ?? '',
            customerPhone: json['customerPhone'],
      driverPhone: json['driverPhone'],
      confirmedAt: json['confirmedAt'],
      cancelDeadline: json['cancelDeadline'],
    );
  }
}

// Converts the raw backend value (e.g. "SIZE_2000L") into a display label,
// for screens that only have the String from an Order, not the enum.
extension TankerSizeLabelX on String {
  String get asTankerSizeLabel {
    switch (this) {
      case 'SIZE_1000L':
        return '1000L';
      case 'SIZE_2000L':
        return '2000L';
      case 'SIZE_3000L':
        return '3000L';
      case 'SIZE_5000L':
        return '5000L';
      default:
        return this;
    }
  }

  int get asGallons {
    switch (this) {
      case 'SIZE_1000L':
        return 264;
      case 'SIZE_2000L':
        return 528;
      case 'SIZE_3000L':
        return 793;
      case 'SIZE_5000L':
        return 1321;
      default:
        return 0;
    }
  }
}