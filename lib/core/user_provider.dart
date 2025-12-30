import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  AppUser? currentUser;
  List<AppUser> _allUsers = [];
  bool _isLoading = false;

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AppUser> get allUsers => _allUsers;
  bool get isLoading => _isLoading;

  Future<void> loadUser() async {
    final sessionUser = _supabase.auth.currentUser;
    if (sessionUser != null) {
      final data = await _authService.getHomeUsersData();
      if (data != null) {
        currentUser = data.currentUser;
        notifyListeners();
      }
    }
  }

  Future<void> refreshUser() async {
    if (currentUser == null) return;
    final updatedData = await _authService.getHomeUsersData();
    if (updatedData != null) {
      currentUser = updatedData.currentUser;
      notifyListeners();
    }
  }

  void clearUser() {
    currentUser = null;
    _allUsers = [];
    notifyListeners();
  }

  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      // CHANGED TO 'users'
      final data = await _supabase.from('users').select().order('name');
      _allUsers = (data as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      // CHANGED TO 'users'
      await _supabase.from('users').update({'role': newRole}).eq('id', userId);
      int index = _allUsers.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _allUsers[index].role = newRole;
      }
      if (currentUser?.id == userId) {
        currentUser?.role = newRole;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // CHANGED TO 'users'
      await _supabase.from('users').delete().eq('id', userId);
      _allUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }
}
