// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchAllUsers();
    });
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length >= 2) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    }
    return nameParts[0][0].toUpperCase();
  }

  void _changeRole(String userId, String newRole) {
    HapticFeedback.mediumImpact();
    Provider.of<UserProvider>(
      context,
      listen: false,
    ).updateUserRole(userId, newRole);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Role changed to $newRole"),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeUser(String userId, String userName) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to remove $userName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<UserProvider>(
                context,
                listen: false,
              ).deleteUser(userId);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);

    // Get current logged in User ID from Supabase
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Separate current user from the rest
    final allUsers = userProvider.allUsers;
    final otherUsers = allUsers.where((u) => u.id != currentUserId).toList();
    final currentUserData = allUsers
        .where((u) => u.id == currentUserId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Manage Users', showPfp: false),
      body: userProvider.isLoading
          ? Center(child: CustomLoader())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: allUsers.isEmpty
                  ? const Center(child: Text("No users found"))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // --- SECTION: CURRENT USER (Non-expandable) ---
                        if (currentUserData != null) ...[
                          _buildSectionHeader("You", isDark),
                          _buildUserCard(
                            user: currentUserData,
                            isDark: isDark,
                            isCurrentUser: true,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // --- SECTION: OTHER USERS ---
                        if (otherUsers.isNotEmpty) ...[
                          _buildSectionHeader("Others", isDark),
                          ...otherUsers.asMap().entries.map((entry) {
                            int index = entry.key;
                            var user = entry.value;
                            return _buildUserCard(
                              user: user,
                              isDark: isDark,
                              index: index,
                              isExpanded: _expandedIndex == index,
                              isCurrentUser: false,
                            );
                          }),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required dynamic user,
    required bool isDark,
    int? index,
    bool isExpanded = false,
    required bool isCurrentUser,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: isDark ? AppColors.primary.withOpacity(0.5) : AppColors.secondary.withOpacity(0.5), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: isDark
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.secondary.withOpacity(0.2),
                child: Text(
                  _getInitials(user.name),
                  style: TextStyle(
                    color: isDark ? AppColors.primary : AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(user.role),
              trailing: isCurrentUser
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Me",
                        style: TextStyle(
                          color: isDark ? AppColors.primary : AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: isExpanded ? 0.5 : 0,
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ),
              onTap: isCurrentUser
                  ? null // Disable clicking for current user
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                      });
                    },
            ),
            if (!isCurrentUser)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? _buildActionButtons(user)
                    : const SizedBox(width: double.infinity, height: 0),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(dynamic user) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  onSelected: (role) => _changeRole(user.id, role),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: "Warehouse",
                      child: Text("Warehouse"),
                    ),
                    const PopupMenuItem(value: "Admin", child: Text("Admin")),
                    const PopupMenuItem(value: "Owner", child: Text("Owner")),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color:  AppColors.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Change Role",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _removeUser(user.id, user.name),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text(
                    "Remove User",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}