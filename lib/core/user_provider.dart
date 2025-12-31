import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  AppUser? currentUser;
  List<AppUser> _allUsers = [];
  List<AppClient> _allClients = []; // Added Client List
  bool _isLoading = false;

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<AppUser> get allUsers => _allUsers;
  List<AppClient> get allClients => _allClients; // Added Getter
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
    _allClients = [];
    notifyListeners();
  }

  // --- USER METHODS ---

  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
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
      await _supabase.from('users').delete().eq('id', userId);
      _allUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  // --- CLIENT METHODS ---

  Future<void> fetchAllClients() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _supabase.from('clients').select().order('name');
      _allClients = (data as List)
          .map((json) => AppClient.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint("Fetch Clients Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteClient(String clientId) async {
    try {
      await _supabase.from('clients').delete().eq('id', clientId);
      _allClients.removeWhere((c) => c.id == clientId);
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Client Error: $e");
    }
  }
}
