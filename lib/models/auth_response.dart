class AuthResponse {
  final String token;
  final String userId; // CHANGED: was int, but backend sends a UUID string
  final String name;
  final String role;
  final String? phone; // null until a call that actually returns it succeeds

  AuthResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
    this.phone,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      userId: json['userId']?.toString() ?? '', // CHANGED: read as string, not int
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      phone: json['phone']?.toString(),
    );
  }
}