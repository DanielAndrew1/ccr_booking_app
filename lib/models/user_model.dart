class AppUser {
  final String id; // UUID String
  final String name;
  final String email;
  String role;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['name'] ?? 'No Name',
      email: json['email'] ?? '',
      role: json['role'] ?? 'Warehouse',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}

class AppClient {
  final String id;
  final String name;
  final String? email;
  final String? phone; // Add this line

  AppClient({
    required this.id,
    required this.name,
    this.email,
    this.phone, // Add this line
  });

  factory AppClient.fromJson(Map<String, dynamic> json) {
    return AppClient(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'], // Add this line
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone, // Add this line
    };
  }
}
