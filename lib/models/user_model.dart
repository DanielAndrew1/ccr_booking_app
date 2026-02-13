class AppUser {
  final String id; // UUID String
  final String name;
  final String email;
  String role;
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['name'] ?? 'No Name',
      email: json['email'] ?? '',
      role: json['role'] ?? 'Warehouse',
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatar_url': avatarUrl,
    };
  }
}

class AppClient {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  AppClient({required this.id, required this.name, this.email, this.phone});

  factory AppClient.fromJson(Map<String, dynamic> json) {
    return AppClient(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'phone': phone};
  }
}

// ADDED: AppBooking model for statistics and revenue tracking
class AppBooking {
  final String id;
  final String clientName;
  final double total; // Used for Revenue calculation
  final String status; // e.g., 'confirmed', 'pending', 'canceled', 'deleted'
  final DateTime? createdAt;

  AppBooking({
    required this.id,
    required this.clientName,
    required this.total,
    required this.status,
    this.createdAt,
  });

  factory AppBooking.fromJson(Map<String, dynamic> json) {
    return AppBooking(
      id: json['id'] ?? '',
      clientName: json['client_name'] ?? 'Unknown',
      // Handles both int and double from Supabase
      total: (json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_name': clientName,
      'total': total,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
