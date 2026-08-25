class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String? lastNameChangeAt;
  final String? undoDeadline;

  UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.lastNameChangeAt,
    this.undoDeadline,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? '',
      lastNameChangeAt: json['lastNameChangeAt'],
      undoDeadline: json['undoDeadline'],
    );
  }
}