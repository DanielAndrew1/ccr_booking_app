// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/main.dart';
import 'package:ccr_booking/pages/clients_page.dart';
import 'package:ccr_booking/pages/users_page.dart';
import 'package:ccr_booking/pages/home_page.dart' hide NoInternetWidget;
import 'package:ccr_booking/widgets/custom_bg_svg.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Added for the decoration
import '../core/app_theme.dart';
import '../pages/edit_info_page.dart';
import '../pages/login_page.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_loader.dart';
import '../widgets/custom_pfp.dart';
import '../widgets/custom_tile.dart';

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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      _checkStatus(result);
    });
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(() {
        _hasConnection = !result.contains(ConnectivityResult.none);
      });
    }
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

    if (updated == true && mounted) {
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
        body: Stack(
          children: [
            // --- MATCHED DECORATION TO HOME PAGE ---
            CustomBgSvg(),

            Column(
              children: [
                if (!_hasConnection)
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: NoInternetWidget(),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Adjusted spacing to account for the decoration positioning
                          const SizedBox(height: 100),

                          // --- PROFILE HEADER ---
                          const Center(
                            child: CustomPfp(dimentions: 140, fontSize: 65),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            currentUser.name,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              currentUser.role,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.primary
                                    : AppColors.secondary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),
                          const Divider(thickness: 0.5),
                          const SizedBox(height: 20),

                          // --- SETTINGS SECTION ---
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
                          const SizedBox(height: 12),
                          CustomTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit Personal Info',
                            onTap: () => _editProfile(context),
                          ),
                          const SizedBox(height: 12),

                          if (currentUser.role == 'Owner') ...[
                            CustomTile(
                              icon: Icons.manage_accounts_rounded,
                              title: 'User Management',
                              route: const UsersPage(),
                            ),
                            const SizedBox(height: 12),
                            CustomTile(
                              icon: Icons.manage_accounts_rounded,
                              title: 'Client Management',
                              route: const ClientsPage(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 40),

                          CustomButton(
                            onPressed: () => _logout(context),
                            icon: Icons.logout_rounded,
                            text: "Logout",
                            color: WidgetStateProperty.all(Colors.red),
                          ),

                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
