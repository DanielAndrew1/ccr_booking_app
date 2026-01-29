// ignore_for_file: deprecated_member_use, unused_element_parameter

import '../core/imports.dart';

class CustomNavbar extends StatefulWidget {
  final int initialIndex;
  const CustomNavbar({super.key, this.initialIndex = 0});

  static Widget buildIcon({
    String? imagePath,
    IconData? icon,
    required Color color,
    double size = 26,
    bool isAdd = false,
  }) {
    if (imagePath != null) {
      if (imagePath.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(
          imagePath,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      } else {
        return Image.asset(imagePath, width: size, height: size, color: color);
      }
    }
    return Icon(icon, color: color, size: size);
  }

  @override
  State<CustomNavbar> createState() => _CustomNavbarState();
}

class _CustomNavbarState extends State<CustomNavbar> {
  late int _currentIndex;
  // Track the last tapped index to trigger the bounce
  int? _tappedIndex;

  final GlobalKey<CalendarPageState> _calendarKey =
      GlobalKey<CalendarPageState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTap(int pageIndex, bool isAddButton) {
    HapticFeedback.mediumImpact(); // Slightly stronger feedback for the bounce

    // Trigger the bounce animation
    setState(() {
      _tappedIndex = pageIndex;
    });

    // Reset the bounce scale after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _tappedIndex = null;
        });
      }
    });

    if (isAddButton) {
      _showAddBottomSheet();
    } else {
      if (pageIndex == 1 && _currentIndex == 1) {
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
        height: 250,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AddListTile(
                    imagePath: "assets/calendar.svg",
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
                    imagePath: "assets/box.svg",
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
                    imagePath: "assets/profile-2user.svg",
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
      _NavItemData(imagePath: "assets/home-2.svg", label: 'Home', pageIndex: 0),
      _NavItemData(
        imagePath: "assets/calendar.svg",
        label: 'Calendar',
        pageIndex: 1,
      ),
    ];

    if (currentUser?.role == 'Admin' || currentUser?.role == 'Owner') {
      navItems.add(
        _NavItemData(
          imagePath: "assets/add-square.svg",
          label: 'Add',
          isAddButton: true,
          pageIndex: -1,
        ),
      );
    }

    navItems.add(
      _NavItemData(
        imagePath: "assets/box.svg",
        label: 'Inventory',
        pageIndex: 2,
      ),
    );
    navItems.add(
      _NavItemData(
        imagePath: "assets/user.svg",
        label: 'Profile',
        pageIndex: 3,
      ),
    );

    final bool shouldShowBlackIcons = (_currentIndex == 3 && !isDark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: shouldShowBlackIcons
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: shouldShowBlackIcons
            ? Brightness.light
            : Brightness.dark,
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
                            final activeColor = isActive
                                ? AppColors.primary
                                : (isDark ? Colors.grey[400]! : Colors.grey);

                            // The bounce happens if this item is currently being tapped
                            final isTapped = _tappedIndex == data.pageIndex;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _onTap(data.pageIndex, data.isAddButton),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 6),
                                    // AnimatedScale provides the bounce effect
                                    AnimatedScale(
                                      scale: isTapped ? 0.88 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      curve: Curves.easeInOut,
                                      child: CustomNavbar.buildIcon(
                                        imagePath: data.imagePath,
                                        icon: data.icon,
                                        color: activeColor,
                                        isAdd: data.isAddButton,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: activeColor,
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
  final IconData? icon;
  final String? imagePath;
  final String label;
  final bool isAddButton;
  final int pageIndex;

  _NavItemData({
    this.icon,
    this.imagePath,
    required this.label,
    this.isAddButton = false,
    required this.pageIndex,
  });
}

class _AddListTile extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String title;
  final VoidCallback onTap;

  const _AddListTile({
    this.icon,
    required this.title,
    required this.onTap,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ListTile(
      leading: CustomNavbar.buildIcon(
        imagePath: imagePath,
        icon: icon,
        color: AppColors.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: isDark ? Colors.white54 : Colors.grey,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
