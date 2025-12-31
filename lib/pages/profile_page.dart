// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/clients_page.dart';
import 'package:ccr_booking/pages/users_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/app_theme.dart';
import '../pages/edit_info_page.dart';
import '../pages/login_page.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_loader.dart';
import '../widgets/custom_pfp.dart';
import '../widgets/custom_tile.dart';
import 'home_page.dart'; // To access NoInternetWidget

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _checkStatus,
    );
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    setState(() {
      _hasConnection = !result.contains(ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditInfoPage(onSaved: () => Navigator.pop(context, true)),
      ),
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
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    final isDark = themeProvider.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        body: Column(
          children: [
            // Adds the internet error banner at the very top if connection is lost
            if (!_hasConnection)
              Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: const NoInternetWidget(),
              ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),

                      // --- PROFILE HEADER ---
                      const Center(
                        child: CustomPfp(dimentions: 140, fontSize: 65),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        currentUser.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currentUser.role,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- SETTINGS SECTION ---
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Settings",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      CustomTile(
                        title: "Dark Mode",
                        icon: Icons.dark_mode,
                        trailing: CupertinoSwitch(
                          value: isDark,
                          onChanged: (v) => themeProvider.toggleTheme(v),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- ACCOUNT SECTION ---
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Account",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      CustomTile(
                        title: "Edit Profile",
                        icon: Icons.person_outline,
                        onTap: () => _editProfile(context),
                      ),

                      // Show Users Management only for Admin or Owner
                      if (currentUser.role == 'Admin' || currentUser.role == 'Owner')
                        CustomTile(
                          title: "Users",
                          icon: Icons.group_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UsersPage(),
                            ),
                          ),
                        ),
                        CustomTile(
                          title: "Clients",
                          icon: Icons.people_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ClientsPage(),
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // --- LOGOUT BUTTON ---
                      CustomButton(
                        text: "Logout",
                        color: WidgetStateProperty.all(AppColors.primary),
                        onPressed: () => _logout(context),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
