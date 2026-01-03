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
  final String id; // UUID String
  final String name;
  final String? email;

  AppClient({required this.id, required this.name, this.email});

  factory AppClient.fromJson(Map<String, dynamic> json) {
    return AppClient(
      id: json['id'] as String, // Direct cast for UUID
      name: json['name'] ?? 'No Name',
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email};
  }
}
