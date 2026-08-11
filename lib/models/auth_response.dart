class AuthResponse {
  final String token;
  final int userId;
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
      userId: json['userId'] ?? 0,
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }
}
