import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

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
    if (user == null) throw 'Registration failed';

    // CHANGED TO 'users'
    await _client.from('users').insert({
      'id': user.id,
      'name': name,
      'email': email,
      'role': 'Warehouse',
    });
  }

  Future<void> login({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<HomeUsersData?> getHomeUsersData() async {
    final currentAuthUser = _client.auth.currentUser;
    if (currentAuthUser == null) return null;

    // CHANGED TO 'users'
    final response = await _client.from('users').select();
    final users = (response as List).map((u) => AppUser.fromJson(u)).toList();

    try {
      final currentUser = users.firstWhere((u) => u.id == currentAuthUser.id);
      final otherUsers = users
          .where((u) => u.id != currentAuthUser.id)
          .toList();

      return HomeUsersData(currentUser: currentUser, otherUsers: otherUsers);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUser({
    required String name,
    required String email,
    String? password,
    String? avatarUrl,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw 'No logged in user';

    // CHANGED TO 'users'
    final updates = {'name': name, 'email': email};
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }
    await _client.from('users').update(updates).eq('id', currentUser.id);

    if (email != currentUser.email) {
      await _client.auth.updateUser(UserAttributes(email: email));
    }

    if (password != null && password.isNotEmpty) {
      await _client.auth.updateUser(UserAttributes(password: password));
    }
  }
}

class HomeUsersData {
  final AppUser currentUser;
  final List<AppUser> otherUsers;

  HomeUsersData({required this.currentUser, required this.otherUsers});
}
