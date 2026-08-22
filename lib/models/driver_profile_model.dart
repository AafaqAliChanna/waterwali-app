class DriverProfile {
  final String id;
  final String name;
  final String? photoUrl;
  final String? vehicleModel;
  final String? vehiclePlateNumber;
  final double averageRating;
  final int totalReviews;

  DriverProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.vehicleModel,
    this.vehiclePlateNumber,
    required this.averageRating,
    required this.totalReviews,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      photoUrl: json['photoUrl'],
      vehicleModel: json['vehicleModel'],
      vehiclePlateNumber: json['vehiclePlateNumber'],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] ?? 0,
    );
  }
}