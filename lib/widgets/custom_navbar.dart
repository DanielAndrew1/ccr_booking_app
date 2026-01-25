// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/add/add_booking.dart';
import 'package:ccr_booking/pages/add/add_client.dart';
import 'package:ccr_booking/pages/add/add_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../pages/home_page.dart';
import '../pages/calendar_page.dart';
import '../pages/inventory_page.dart';
import '../pages/profile_page.dart';

class CustomNavbar extends StatefulWidget {
  final int initialIndex;
  const CustomNavbar({super.key, this.initialIndex = 0});

  @override
  State<CustomNavbar> createState() => _CustomNavbarState();
}

class _CustomNavbarState extends State<CustomNavbar> {
  late int _currentIndex;

  // GlobalKey to access Calendar reset logic
  final GlobalKey<CalendarPageState> _calendarKey =
      GlobalKey<CalendarPageState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTap(int pageIndex, bool isAddButton) {
    HapticFeedback.lightImpact();

    if (isAddButton) {
      _showAddBottomSheet();
    } else {
      // Logic for Calendar tab reset
      if (pageIndex == 1) {
        _calendarKey.currentState?.resetToToday();
      }
      setState(() => _currentIndex = pageIndex);
    }
  }

  void _showAddBottomSheet() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkbg : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: 230,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AddListTile(
              icon: Icons.calendar_month_rounded,
              title: 'Add Booking',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddBooking()),
                );
              },
            ),
            _AddListTile(
              icon: Icons.inventory_2_outlined,
              title: 'Add Product',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProduct()),
                );
              },
            ),
            _AddListTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Add Client',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddClient()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final List<Widget> pages = [
      const HomePage(),
      CalendarPage(key: _calendarKey),
      const InventoryPage(),
      const ProfilePage(),
    ];

    final List<_NavItemData> navItems = [
      _NavItemData(icon: Icons.home_rounded, label: 'Home', pageIndex: 0),
      _NavItemData(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        pageIndex: 1,
      ),
    ];

    if (currentUser?.role == 'Admin' || currentUser?.role == 'Owner') {
      navItems.add(
        _NavItemData(
          icon: Icons.add_rounded,
          label: 'Add',
          isAddButton: true,
          pageIndex: -1,
        ),
      );
    }

    navItems.add(
      _NavItemData(
        icon: Icons.inventory_2_outlined,
        label: 'Inventory',
        pageIndex: 2,
      ),
    );
    navItems.add(
      _NavItemData(icon: Icons.person_rounded, label: 'Profile', pageIndex: 3),
    );

    // --- STATUS BAR LOGIC ---
    // Rule: Icons are always white (Brightness.light)
    // EXCEPT when on Profile (index 3) AND the app is in light mode.
    final bool shouldShowBlackIcons = (_currentIndex == 3 && !isDark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Brightness.dark for icons actually means "Icons for dark backgrounds" (which are white)
        // Brightness.light for icons actually means "Icons for light backgrounds" (which are black)
        // Note: Flutter's terminology can be confusing, but setting brightness to
        // light results in dark icons on Android and vice versa.
        statusBarIconBrightness: shouldShowBlackIcons
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: shouldShowBlackIcons
            ? Brightness.light
            : Brightness.dark, // iOS
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: pages),
            Positioned(
              left: 16,
              right: 16,
              bottom: 35,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / navItems.length;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Builder(
                          builder: (context) {
                            int activeIndex = navItems.indexWhere(
                              (item) => item.pageIndex == _currentIndex,
                            );
                            if (activeIndex == -1) activeIndex = 0;
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              left:
                                  activeIndex * itemWidth +
                                  (itemWidth - 24) / 2,
                              top: 0,
                              child: Container(
                                width: 24,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: navItems.map((data) {
                            final isActive = data.pageIndex == _currentIndex;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _onTap(data.pageIndex, data.isAddButton),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 6),
                                    Icon(
                                      data.icon,
                                      color: isActive
                                          ? AppColors.primary
                                          : (isDark
                                                ? Colors.grey[400]
                                                : Colors.grey),
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isActive
                                            ? AppColors.primary
                                            : (isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey),
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final bool isAddButton;
  final int pageIndex;

  _NavItemData({
    required this.icon,
    required this.label,
    this.isAddButton = false,
    required this.pageIndex,
  });
}

class _AddListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AddListTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isDark ? Colors.white54 : Colors.grey,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
