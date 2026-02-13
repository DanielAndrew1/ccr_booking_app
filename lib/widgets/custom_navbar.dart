// ignore_for_file: deprecated_member_use, unused_element_parameter, must_be_immutable

import '../core/imports.dart';

class CustomNavbar extends StatefulWidget {
  int initialIndex;
  CustomNavbar({super.key, this.initialIndex = 0});

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
  int? _tappedIndex;
  bool _isMenuOpen = false;

  final GlobalKey<CalendarPageState> _calendarKey =
      GlobalKey<CalendarPageState>();
  final GlobalKey<BookingsPageState> _bookingsKey =
      GlobalKey<BookingsPageState>();

  @override
  void initState() {
    super.initState();
    // Initialize the provider with the initial index if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavbarProvider>(
        context,
        listen: false,
      ).setIndex(widget.initialIndex);
    });
  }

  void _triggerBounce(int pageIndex) {
    setState(() => _tappedIndex = pageIndex);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _tappedIndex = null);
    });
  }

  void _onTap(int pageIndex, bool isAddButton) {
    final navProvider = Provider.of<NavbarProvider>(context, listen: false);
    final int currentIndex = navProvider.selectedIndex;

    bool isAlreadySelected = isAddButton
        ? (currentIndex == 4 || currentIndex == 5 || currentIndex == 6)
        : (currentIndex == pageIndex);

    if (!isAlreadySelected) {
      HapticFeedback.lightImpact();
      _triggerBounce(pageIndex);
    }

    if (isAddButton) {
      navProvider.setIndex(4);
      setState(() => _isMenuOpen = false);
    } else {
      if (pageIndex == 1 && currentIndex == 1) {
        _calendarKey.currentState?.resetToToday();
      }
      navProvider.setIndex(pageIndex);
      setState(() => _isMenuOpen = false);
      if (pageIndex == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _bookingsKey.currentState?.resetToToday();
        });
      }
    }
  }

  void _onLongPress(bool isAddButton) {
    if (isAddButton) {
      HapticFeedback.mediumImpact();
      setState(() => _isMenuOpen = !_isMenuOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final navProvider = Provider.of<NavbarProvider>(context); // Listen to index
    final bookingProvider = Provider.of<BookingProvider>(
      context,
    ); // Listen to edit mode
    final loc = AppLocalizations.of(context);

    final int currentIndex = navProvider.selectedIndex;
    final bool isEditing = bookingProvider.editingBooking != null;
    final currentUser = userProvider.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bool canUseAddMenu = (currentUser?.role == 'Admin' || currentUser?.role == 'Owner') && !isEditing;

    if (!canUseAddMenu && _isMenuOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isMenuOpen = false);
      });
    }

    final List<Widget> pages = [
      const HomePage(),
      CalendarPage(key: _calendarKey),
      BookingsPage(key: _bookingsKey),
      const ProfilePage(),
      isEditing ? const EditBooking() : const AddBooking(isRoot: true),
      const AddClient(isRoot: true),
      const AddProduct(isRoot: true),
    ];

    final String todayDay = DateTime.now().day.toString();
    final List<_NavItemData> navItems = [
      _NavItemData(
        imagePath: AppIcons.home,
        label: loc.tr('Home'),
        pageIndex: 0,
      ),
      _NavItemData(
        imagePath: AppIcons.calendar,
        label: loc.tr('Calendar'),
        pageIndex: 1,
      ),
    ];

    if (currentUser?.role == 'Admin' || currentUser?.role == 'Owner') {
      navItems.add(
        _NavItemData(
          imagePath: isEditing ? AppIcons.edit : AppIcons.add,
          label: loc.tr(isEditing ? 'Edit' : 'Add'),
          isAddButton: !isEditing,
          pageIndex: 4,
        ),
      );
    }

    navItems.add(
      _NavItemData(
        imagePath: AppIcons.booking,
        label: loc.tr('Bookings'),
        pageIndex: 2,
        badgeText: todayDay,
      ),
    );
    navItems.add(
      _NavItemData(
        imagePath: AppIcons.profile,
        label: loc.tr('Profile'),
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
            child: IndexedStack(index: currentIndex, children: pages),
          ),

          if (canUseAddMenu)
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

          _buildBottomNavbar(navItems, isDark, currentIndex),

          if (canUseAddMenu)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              bottom: _isMenuOpen ? 115 : 70,
              left: MediaQuery.of(context).size.width / 2 - 110,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isMenuOpen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 220,
                        height: _isMenuOpen ? 145 : 0,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2C)
                              : Colors.white,
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
                                  imagePath: AppIcons.userAdd,
                                  title: loc.tr("Add Client"),
                                  onTap: () => _onTap(5, false),
                                ),
                                _buildDivider(isDark),
                                _MenuEntry(
                                  imagePath: AppIcons.inventory,
                                  title: loc.tr("Add Product"),
                                  onTap: () => _onTap(6, false),
                                ),
                                _buildDivider(isDark),
                                _MenuEntry(
                                  imagePath: AppIcons.calendarAdd,
                                  title: loc.tr("Add Booking"),
                                  onTap: () => _onTap(4, false),
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
            _buildBottomNavbar(
              navItems,
              isDark,
              currentIndex,
              isOpaqueLayer: true,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavbar(
    List<_NavItemData> navItems,
    bool isDark,
    int currentIndex, {
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
                        return currentIndex == 4 ||
                            currentIndex == 5 ||
                            currentIndex == 6;
                      }
                      return item.pageIndex == currentIndex;
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
                        ? (currentIndex == 4 ||
                              currentIndex == 5 ||
                              currentIndex == 6)
                        : (data.pageIndex == currentIndex);

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
                              scale: isTapped ? 0.9 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: TweenAnimationBuilder<Color?>(
                                duration: const Duration(milliseconds: 200),
                                tween: ColorTween(
                                  begin: inactiveColor,
                                  end: isSectionActive
                                      ? activeColor
                                      : inactiveColor,
                                ),
                                builder: (context, color, child) {
                                  final iconWidget = CustomNavbar.buildIcon(
                                    imagePath: data.imagePath,
                                    color: color ?? inactiveColor,
                                  );
                                  if (data.badgeText == null) {
                                    return iconWidget;
                                  }
                                  final badgeTextColor = isSectionActive
                                      ? AppColors.primary
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.grey.shade500);
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      iconWidget,
                                      Positioned(
                                        bottom: 9,
                                        right: 7,
                                        child: Container(
                                          width: 12,
                                          height: 13,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color:
                                                data.badgeColor ??
                                                (isDark
                                                    ? Color(0xFF252525)
                                                    : Colors.white),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            data.badgeText!,
                                            style: TextStyle(
                                              color: badgeTextColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
  final String? badgeText;
  final Color? badgeColor;
  final Color? badgeTextColor;
  _NavItemData({
    this.imagePath,
    required this.label,
    this.isAddButton = false,
    required this.pageIndex,
    this.badgeText,
    this.badgeColor,
    this.badgeTextColor,
  });
}
