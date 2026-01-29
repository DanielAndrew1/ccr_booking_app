// lib/pages/profile_page.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../core/imports.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;
  final ScrollController _scrollController = ScrollController();
  bool _showCompactHeader = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      _checkStatus(result);
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 240 && !_showCompactHeader) {
        setState(() => _showCompactHeader = true);
      } else if (_scrollController.offset <= 240 && _showCompactHeader) {
        setState(() => _showCompactHeader = false);
      }
    });
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(
        () => _hasConnection = !result.contains(ConnectivityResult.none),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _scrollController.dispose();
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

  Future<void> _confirmDeleteAccount() async {
    final bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action is permanent and cannot be undone.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Delete"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('users').delete().eq('id', userId);
        await _logout(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditInfoPage(onSaved: () => Navigator.pop(context, true)),
      ),
    );
  }

  Widget _buildStickyAppBar(dynamic currentUser, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: AppColors.secondary,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: AppColors.lightcolor,
            toolbarHeight: 80,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                const CustomPfp(dimentions: 45, fontSize: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentUser.name,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4,),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentUser.role,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        body: Stack(
          children: [
            const CustomBgSvg(),
            Column(
              children: [
                if (!_hasConnection) const NoInternetWidget(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Hero(
                              tag: 'profile_image',
                              // Material wrapper removes the yellow underline during transition
                              child: Material(
                                type: MaterialType.transparency,
                                child: CustomPfp(dimentions: 140, fontSize: 60),
                              ),
                            ),
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
                          const SizedBox(height: 10),
                          CustomTile(
                            title: "Dark Mode",
                            icon: Icons.dark_mode_outlined,
                            trailing: CupertinoSwitch(
                              value: isDark,
                              activeTrackColor: AppColors.primary,
                              onChanged: (value) =>
                                  themeProvider.toggleTheme(value),
                            ),
                          ),
                          CustomTile(
                            imagePath: "assets/user.svg",
                            title: 'Edit Info',
                            onTap: () => _editProfile(context),
                          ),
                          if (currentUser.role == 'Owner') ...[
                            CustomTile(
                              imagePath: "assets/user-search.svg",
                              title: 'Employee Management',
                              route: const UsersPage(),
                            ),
                            CustomTile(
                              imagePath: "assets/profile-2user.svg",
                              title: 'Client Management',
                              route: const ClientsPage(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          CustomTile(
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            textColor: const Color(0xFFFF1100),
                            onTap: () => _logout(context),
                          ),
                          const SizedBox(height: 20),
                          CustomButton(
                            onPressed: _confirmDeleteAccount,
                            imagePath: "assets/trash.svg",
                            height: 50,
                            text: "Delete Account",
                            color: WidgetStateProperty.all(
                              const Color(0xFFFF1100),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "App Version ${AppVersion.version}",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showCompactHeader ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showCompactHeader,
                  child: _buildStickyAppBar(currentUser, isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
