// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_field, non_constant_identifier_names, unnecessary_string_interpolations

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
  String _appVersion = ""; // Use underscore for private

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Load everything at once
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

  // Load App Version
  Future<void> _loadInitialData() async {
    final version = await AppVersionPlus.appVersion();
    if (mounted) {
      setState(() {
        _appVersion = version;
      });
    }
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
      builder: (context) => CustomAlertDialogue(
        icon: AppIcons.trash,
        title: "Delete Account",
        body: "Are you sure you want to delete your account?",
        confirm: 'Delete',
      ),
    );
    if (confirm == true) _deleteAccount();
  }

  Future<void> _confirmLogout() async {
    final bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CustomAlertDialogue(
        icon: AppIcons.logout,
        title: "Log Out",
        body: "Are you sure you want to log out?",
        confirm: 'Log Out',
      ),
    );
    if (confirm == true) _logout(context);
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
      CustomSnackBar.show(context, "Error: $e");
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
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final loc = AppLocalizations.of(context);
    return ClipRRect(
      child: Container(
        color: isDark ? AppColors.secondary : AppColors.primary,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          automaticallyImplyLeading: false,
          title: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              const CustomPfp(dimentions: 45, fontSize: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Text(
                        currentUser.name,
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (currentUser.name == "Daniel Andrew" &&
                          currentUser.email ==
                              "danielandrew1207@gmail.com") ...{
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          AppIcons.verify,
                          width: 18,
                          color: Colors.white,
                        ),
                      },
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      loc.tr(currentUser.role),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.primary : AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    final loc = AppLocalizations.of(context);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

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
            const CustomBgSvg(),
            Column(
              children: [
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
                              child: Material(
                                type: MaterialType.transparency,
                                child: const CustomPfp(
                                  dimentions: 140,
                                  fontSize: 60,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (currentUser.name == "Daniel Andrew" && currentUser.email == "danielandrew1207@gmail.com") ...{
                                const SizedBox(width: 30),
                              },
                              Text(
                                currentUser.name,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              if (currentUser.name == "Daniel Andrew" && currentUser.email == "danielandrew1207@gmail.com") ...{
                                const SizedBox(width: 8),
                                SvgPicture.asset(
                                  AppIcons.verify,
                                  width: 22,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              },
                            ],
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
                            imagePath: AppIcons.profile,
                            title: 'Profile',
                            onTap: () => _editProfile(context),
                          ),

                          if (currentUser.role == 'Owner') ...[
                            CustomTile(
                              imagePath: AppIcons.userSearch,
                              title: loc.tr('Employees'),
                              route: UsersPage(),
                            ),
                            CustomTile(
                              imagePath: AppIcons.client,
                              title: loc.tr('Clients'),
                              route: ClientsPage(),
                            ),
                            CustomTile(
                              imagePath: AppIcons.inventory,
                              title: loc.tr('Inventory'),
                              route: InventoryPage(),
                              overlayColor: true,
                            ),
                          ],
                          CustomTile(
                            imagePath: AppIcons.settings,
                            title: loc.tr('Settings'),
                            route: const SettingsPage(),
                          ),
                          CustomTile(
                            imagePath: AppIcons.globe,
                            title: loc.tr('About'),
                            route: AboutPage(),
                          ),
                          const SizedBox(height: 6),
                          CustomTile(
                            imagePath: AppIcons.logout,
                            title: loc.tr('Log Out'),
                            textColor: AppColors.red,
                            onTap: () => _confirmLogout(),
                          ),
                          const SizedBox(height: 18),
                          CustomButton(
                            onPressed: _confirmDeleteAccount,
                            imagePath: AppIcons.trash,
                            height: 50,
                            text: loc.tr("Delete Account"),
                            color: WidgetStateProperty.all(AppColors.red),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "${AppLocalizations.of(context).tr("App Version $_appVersion")}",
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
