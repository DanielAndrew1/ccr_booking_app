import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 1. Import this
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../pages/edit_info_page.dart';
import '../pages/login_page.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_loader.dart';
import '../widgets/custom_pfp.dart';
import '../widgets/custom_tile.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.clearUser();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _editProfile(BuildContext context) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditInfoPage()),
    );
    if (updated == true) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Center(child: CustomLoader());
    }

    final isDark = themeProvider.isDarkMode;

    // 2. Use AnnotatedRegion to control the Status Bar
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // For Android: makes icons white (light) or black (dark)
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        // For iOS: makes icons white (light) or black (dark)
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        // Optional: Set status bar color to transparent to see your background
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 70),
                const CustomPfp(dimentions: 150, fontSize: 72),
                const SizedBox(height: 20),
                Text(
                  currentUser.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentUser.role,
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const Divider(height: 40),

                // --- DARK MODE TILE ---
                CustomTile(
                  title: "Dark Mode",
                  icon: Icons.dark_mode_rounded,
                  trailing: CupertinoSwitch(
                    value: isDark,
                    activeTrackColor: AppColors.primary,
                    onChanged: (value) {
                      themeProvider.toggleTheme(value);
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // --- NAVIGATION TILE ---
                CustomTile(
                  icon: Icons.person_rounded,
                  title: 'Edit Personal Info',
                  route: EditInfoPage(onSaved: () => _editProfile(context)),
                ),

                const SizedBox(height: 10),

                // --- NAVIGATION TILE ---
                CustomTile(
                  icon: Icons.person_rounded,
                  title: 'Users',
                  route: EditInfoPage(onSaved: () => _editProfile(context)),
                ),

                const SizedBox(height: 30),

                CustomButton(
                  onPressed: () => _logout(context),
                  icon: Icons.logout_rounded,
                  text: "Logout",
                  color: WidgetStateProperty.all(Colors.red),
                ),
                const SizedBox(height: 115),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
