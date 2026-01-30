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
  int? _tappedIndex;
  bool _isMenuOpen = false;

  final GlobalKey<CalendarPageState> _calendarKey =
      GlobalKey<CalendarPageState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _triggerBounce(int pageIndex) {
    setState(() => _tappedIndex = pageIndex);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _tappedIndex = null);
    });
  }

  void _onTap(int pageIndex, bool isAddButton) {
    // Determine if this is a "new" selection
    // For AddButton, we check if we are currently in any of the "Add" sub-pages (4, 5, or 6)
    bool isAlreadySelected = isAddButton
        ? (_currentIndex == 4 || _currentIndex == 5 || _currentIndex == 6)
        : (_currentIndex == pageIndex);

    // ONLY trigger haptic and bounce if it's NOT already selected
    if (!isAlreadySelected) {
      HapticFeedback.selectionClick();
      _triggerBounce(pageIndex);
    }

    // Logic for the Add Button
    if (isAddButton) {
      setState(() {
        _currentIndex = 4; // Default to Add Booking
        _isMenuOpen = false;
      });
    } else {
      // Specific logic for Calendar: reset to today even if already selected
      if (pageIndex == 1 && _currentIndex == 1) {
        _calendarKey.currentState?.resetToToday();
      }

      // Update the index
      setState(() {
        _currentIndex = pageIndex;
        _isMenuOpen = false;
      });
    }
  }

  void _onLongPress(bool isAddButton) {
    if (isAddButton) {
      HapticFeedback.lightImpact();
      setState(() => _isMenuOpen = !_isMenuOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final List<Widget> pages = [
      const HomePage(), // 0
      CalendarPage(key: _calendarKey), // 1
      const BookingsPage(), // 2
      const ProfilePage(), // 3
      const AddBooking(isRoot: true), // 4
      const AddClient(isRoot: true), // 5
      const AddProduct(isRoot: true), // 6
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
          pageIndex: 4,
        ),
      );
    }

    navItems.add(
      _NavItemData(
        imagePath: "assets/booking.svg",
        label: 'Bookings',
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.lightcolor,
      body: Stack(
        children: [
          Container(
            color: AppColors.lightcolor,
            child: IndexedStack(index: _currentIndex, children: pages),
          ),

          IgnorePointer(
            ignoring: !_isMenuOpen,
            child: GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: double.infinity,
                color: _isMenuOpen
                    ? Colors.black.withOpacity(0.35)
                    : Colors.transparent,
              ),
            ),
          ),

          _buildBottomNavbar(navItems, isDark),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            bottom: _isMenuOpen ? 115 : 70,
            left: MediaQuery.of(context).size.width / 2 - 110,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMenuOpen ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_isMenuOpen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 220,
                      height: _isMenuOpen ? 153 : 0,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MenuEntry(
                                imagePath: "assets/user-add.svg",
                                title: "Add Client",
                                onTap: () => setState(() {
                                  _currentIndex = 5;
                                  _isMenuOpen = false;
                                }),
                              ),
                              _buildDivider(isDark),
                              _MenuEntry(
                                imagePath: "assets/box.svg",
                                title: "Add Product",
                                onTap: () => setState(() {
                                  _currentIndex = 6;
                                  _isMenuOpen = false;
                                }),
                              ),
                              _buildDivider(isDark),
                              _MenuEntry(
                                imagePath: "assets/calendar-add.svg",
                                title: "Add Booking",
                                onTap: () => setState(() {
                                  _currentIndex = 4;
                                  _isMenuOpen = false;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(20, 10),
                      painter: _TrianglePainter(
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isMenuOpen)
            _buildBottomNavbar(navItems, isDark, isOpaqueLayer: true),
        ],
      ),
    );
  }

  Widget _buildBottomNavbar(
    List<_NavItemData> navItems,
    bool isDark, {
    bool isOpaqueLayer = false,
  }) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 35,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isOpaqueLayer
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(isDark ? 0.1 : 0.15),
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
                    int activeIndex = navItems.indexWhere((item) {
                      if (item.isAddButton) {
                        return _currentIndex == 4 ||
                            _currentIndex == 5 ||
                            _currentIndex == 6;
                      }
                      return item.pageIndex == _currentIndex;
                    });
                    if (activeIndex == -1) activeIndex = 0;
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: activeIndex * itemWidth + (itemWidth - 24) / 2,
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
                    final bool isSectionActive = data.isAddButton
                        ? (_currentIndex == 4 ||
                              _currentIndex == 5 ||
                              _currentIndex == 6)
                        : (data.pageIndex == _currentIndex);

                    final Color activeColor = AppColors.primary;
                    final Color inactiveColor = isDark
                        ? Colors.grey[400]!
                        : Colors.grey;

                    final isTapped = _tappedIndex == data.pageIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTap(data.pageIndex, data.isAddButton),
                        onLongPress: () => _onLongPress(data.isAddButton),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 6),
                            AnimatedScale(
                              scale: isTapped ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: TweenAnimationBuilder<Color?>(
                                duration: const Duration(milliseconds: 300),
                                tween: ColorTween(
                                  begin: inactiveColor,
                                  end: isSectionActive
                                      ? activeColor
                                      : inactiveColor,
                                ),
                                builder: (context, color, child) {
                                  return CustomNavbar.buildIcon(
                                    imagePath: data.imagePath,
                                    color: color ?? inactiveColor,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              style: TextStyle(
                                color: isSectionActive
                                    ? activeColor
                                    : inactiveColor,
                                fontWeight: isSectionActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 11,
                              ),
                              child: Text(data.label),
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
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.white10 : Colors.black12,
      indent: 12,
      endIndent: 12,
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback onTap;
  const _MenuEntry({
    required this.imagePath,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              imagePath,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white70 : Colors.black87,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItemData {
  final String? imagePath;
  final String label;
  final bool isAddButton;
  final int pageIndex;
  _NavItemData({
    this.imagePath,
    required this.label,
    this.isAddButton = false,
    required this.pageIndex,
  });
}
