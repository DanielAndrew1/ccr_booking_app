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

  // Placeholder function for role change
  void _changeRole(String userId, String newRole) {
    HapticFeedback.mediumImpact();
    // Implement your Supabase/Backend logic here
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Role changed to $newRole")));
  }

  // Placeholder function for removal
  void _removeUser(String userId) {
    HapticFeedback.heavyImpact();
    // Implement your deletion logic here
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("User removed")));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);

    // Assuming your provider has a list of users or you fetch them here
    // For now, using a dummy list based on your User model structure
    final List<dynamic> allUsers =
        []; // Replace with userProvider.allUsers if exists

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Manage Users', showPfp: false),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // Replace with allUsers.length
        itemBuilder: (context, index) {
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
                      "U$index",
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  title: Text(
                    "User Name $index",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: const Text("Admin"),
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
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => _changeRole("id", "Admin"),
                                icon: const Icon(
                                  Icons.shield_outlined,
                                  size: 18,
                                ),
                                label: const Text("Change Role"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => _removeUser("id"),
                                icon: const Icon(
                                  Icons.person_remove_outlined,
                                  size: 18,
                                ),
                                label: const Text("Remove"),
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
