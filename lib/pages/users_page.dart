import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    // Load the users from Supabase when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchAllUsers();
    });
  }

  // Helper function to get initials from a specific user's name
  String _getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length >= 2) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    }
    return nameParts[0][0].toUpperCase();
  }

  // Function for role change
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
      ),
    );
  }

  // Function for removal
  void _removeUser(String userId, String userName) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("User removed"),
                  backgroundColor: Colors.red,
                ),
              );
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
    final allUsers = userProvider.allUsers;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Manage Users', showPfp: false),
      body: userProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : allUsers.isEmpty
          ? const Center(child: Text("No users found"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allUsers.length,
              itemBuilder: (context, index) {
                final user = allUsers[index];
                bool isExpanded = _expandedIndex == index;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            _getInitials(user.name),
                            style: TextStyle(
                              color: AppColors.primary,
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
                        trailing: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          child: Column(
                            children: [
                              const Divider(),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // FILLED BUTTON FOR ROLE (NO ICON)
                                  Expanded(
                                    child: PopupMenuButton<String>(
                                      offset: const Offset(0, 45),
                                      onSelected: (String role) =>
                                          _changeRole(user.id, role),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: "Warehouse",
                                          child: Text("Warehouse"),
                                        ),
                                        const PopupMenuItem(
                                          value: "Admin",
                                          child: Text("Admin"),
                                        ),
                                        const PopupMenuItem(
                                          value: "Owner",
                                          child: Text("Owner"),
                                        ),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            "Role",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // REMOVE BUTTON
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _removeUser(user.id, user.name),
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        "Remove",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
