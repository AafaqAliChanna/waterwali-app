class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;

  UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? '',
    );
  }
}