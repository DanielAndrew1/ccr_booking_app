// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import '../core/imports.dart';

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

  // Updated to use CustomSnackBar
  void _changeRole(String userId, String newRole) {
    HapticFeedback.selectionClick();
    Provider.of<UserProvider>(
      context,
      listen: false,
    ).updateUserRole(userId, newRole);

    CustomSnackBar.show(
      context,
      "Role changed to $newRole",
      color: AppColors.primary,
    );
  }

  // Logic to handle the actual deletion and snackbar response
  Future<void> _executeDelete(String userId, String userName) async {
    try {
      await Provider.of<UserProvider>(
        context,
        listen: false,
      ).deleteUser(userId);
      if (mounted) {
        CustomSnackBar.show(
          context,
          '"$userName" removed successfully',
          color: AppColors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          "Error deleting user: ${e.toString()}",
        );
      }
    }
  }

  // Cupertino deletion dialog (Fixed logic and text)
  Future<void> _confirmDeleteUser(String userId, String userName) async {
    HapticFeedback.heavyImpact();
    final bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CustomAlertDialogue(
        icon: AppIcons.trash,
        title: "Delete User",
        body: 'Are you sure you want to delete "$userName"?',
        confirm: "Delete",
      ),
    );

    if (confirm == true) {
      _executeDelete(userId, userName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final userProvider = Provider.of<UserProvider>(context);

    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final allUsers = userProvider.allUsers;

    final currentUserData = allUsers
        .where((u) => u.id == currentUserId)
        .firstOrNull;

    List<dynamic> otherUsers = allUsers
        .where((u) => u.id != currentUserId)
        .toList();
    otherUsers.sort((a, b) {
      if (a.name == "Daniel Andrew") return -1;
      if (b.name == "Daniel Andrew") return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Container(
      color: isDark ? AppColors.darkbg : AppColors.lightcolor,
      child: Stack(
        children: [
          const CustomBgSvg(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: const CustomAppBar(
              text: 'Manage Employees',
              showPfp: false,
            ),
            body: userProvider.isLoading
                ? const Center(child: CustomLoader())
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: allUsers.isEmpty
                        ? const Center(child: Text("No Employees yet."))
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              if (currentUserData != null) ...[
                                _buildSectionHeader("You", isDark),
                                _buildUserCard(
                                  user: currentUserData,
                                  isDark: isDark,
                                  isCurrentUser: true,
                                ),
                                const SizedBox(height: 20),
                              ],
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
          ),
        ],
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
    final bool isDaniel = user.name == "Daniel Andrew";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Color(0x8E2C2C2C) : const Color(0x90FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(
                color: isDark
                    ? AppColors.primary.withOpacity(0.7)
                    : AppColors.secondary.withOpacity(0.7),
                width: 1,
              )
            : null,
      ),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              splashColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
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
              title: Row(
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (isDaniel) ...[
                    const SizedBox(width: 6),
                    SvgPicture.asset(
                      AppIcons.verify,
                      width: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                user.role,
                style:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              trailing: isCurrentUser
                  ? _buildBadge("You", isDark)
                  : isDaniel
                  ? null
                  : AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: isExpanded ? 0.5 : 0,
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ),
              onTap: (isCurrentUser || isDaniel)
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                      });
                    },
            ),
          ),
          if (!isCurrentUser && !isDaniel)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? _buildActionButtons(user)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? AppColors.primary : AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
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
                    const PopupMenuItem(value: "Warehouse", child: Text("Warehouse")),
                    const PopupMenuItem(value: "Admin", child: Text("Admin")),
                    const PopupMenuItem(value: "Owner", child: Text("Owner")),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
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
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // Switching this to the Cupertino style version as an example
                  // or keep _removeUser if you prefer Material.
                  onPressed: () => _confirmDeleteUser(user.id, user.name),
                  icon: SvgPicture.asset(AppIcons.trash, color: Colors.white),
                  label: const Text(
                    "Delete",
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
