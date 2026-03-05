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
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );

    final authUser = response.user ?? _client.auth.currentUser;
    if (authUser == null) {
      throw 'Invalid email or password';
    }

    // Protect against stale local auth state mismatching entered credentials.
    if ((authUser.email ?? '').toLowerCase() != normalizedEmail) {
      await _client.auth.signOut();
      throw 'Invalid email or password';
    }

    final userData = await _client
        .from('users')
        .select('id')
        .eq('id', authUser.id)
        .maybeSingle();

    if (userData == null) {
      await _client.auth.signOut();
      throw 'No app profile found for this account';
    }
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
