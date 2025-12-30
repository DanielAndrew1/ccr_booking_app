import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // REGISTER
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw 'Registration failed';
    }

    await _client.from('users').insert({
      'id': user.id,
      'name': name,
      'email': email,
    });
  }

  // LOGIN
  Future<void> login({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  // LOGOUT
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  // GET HOME USERS DATA
  Future<HomeUsersData?> getHomeUsersData() async {
    final currentAuthUser = _client.auth.currentUser;

    if (currentAuthUser == null) return null;

    final response = await _client.from('users').select();

    final users = (response as List)
        .map(
          (u) => AppUser(name: u['name'], email: u['email'], role: u['role']),
        )
        .toList();

    final currentUser = users.firstWhere(
      (u) => u.email == currentAuthUser.email,
    );

    final otherUsers = users
        .where((u) => u.email != currentAuthUser.email)
        .toList();

    return HomeUsersData(currentUser: currentUser, otherUsers: otherUsers);
  }

  // ------------------ UPDATE USER ------------------
  Future<void> updateUser({
    required String name,
    required String email,
    String? password,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw 'No logged in user';

    // Update the database table
    await _client
        .from('users')
        .update({'name': name, 'email': email})
        .eq('id', currentUser.id);

    // Update auth email if changed
    if (email != currentUser.email) {
      await _client.auth.updateUser(UserAttributes(email: email));
    }

    // Update password if provided
    if (password != null && password.isNotEmpty) {
      await _client.auth.updateUser(UserAttributes(password: password));
    }
  }
}

// MODELS
class AppUser {
  final String name;
  final String email;
  final String role;

  AppUser({required this.name, required this.email, required this.role});
}

class HomeUsersData {
  final AppUser currentUser;
  final List<AppUser> otherUsers;

  HomeUsersData({required this.currentUser, required this.otherUsers});
}
