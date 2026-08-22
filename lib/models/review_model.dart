class Review {
  final String id;
  final String customerName;
  final int rating;
  final String? comment;
  final String createdAt;

  Review({
    required this.id,
    required this.customerName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      customerName: json['customerName'] ?? 'Customer',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}