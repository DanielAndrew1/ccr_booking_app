import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  AppUser? currentUser;
  final AuthService _authService = AuthService();

  /// Loads the user on app start
  Future<void> loadUser() async {
    final sessionUser = Supabase.instance.client.auth.currentUser;
    if (sessionUser != null) {
      final data = await _authService.getHomeUsersData();
      if (data != null) {
        currentUser = data.currentUser;
        notifyListeners();
      }
    }
  }

  /// Sets the current user manually
  void setUser(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  /// Logs out the user locally
  void logout() {
    currentUser = null;
    notifyListeners();
  }

  /// Clears user data
  void clearUser() {
    currentUser = null;
    notifyListeners();
  }

  /// Refreshes current user data from Supabase
  Future<void> refreshUser() async {
    if (currentUser == null) return;

    final updatedData = await _authService.getHomeUsersData();
    if (updatedData != null) {
      currentUser = updatedData.currentUser;
      notifyListeners();
    }
  }
}
