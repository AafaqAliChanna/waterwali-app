class AuthResponse {
  final String token;
  final String userId; // CHANGED: was int, but backend sends a UUID string
  final String name;
  final String role;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      userId: json['userId']?.toString() ?? '', // CHANGED: read as string, not int
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }
}