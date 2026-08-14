// ignore_for_file: deprecated_member_use

part of 'home_page.dart';

class SlidingNumber extends StatelessWidget {
  final String value;
  final TextStyle style;
  const SlidingNumber({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final int? target = int.tryParse(value);
    if (target == null) {
      return Text(value, style: style);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(val.toString(), style: style);
      },
    );
  }
}

extension _HomePageWidgets on _HomePageState {
  Future<void> _handleStatsTap({
    Widget? route,
    VoidCallback? dialogAction,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final openDialog = prefs.getBool('home_stats_dialog') ?? true;
    if (!mounted) return;
    if (openDialog && dialogAction != null) {
      dialogAction();
      return;
    }
    if (route != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => route));
    }
  }

  Widget _buildPopupField(
    String label,
    String value,
    bool isDark, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Row(
            children: [
              if (icon != null) Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDashboard(String role, bool isDark) {
    final loc = AppLocalizations.of(context);
    final sections = <Widget>[];
    void add(Widget section) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 26));
      sections.add(section);
    }

    for (final section in _dashboardSections) {
      switch (section) {
        case 'stats' when role == 'Owner':
          add(_buildOwnerStatsView(isDark));
        case 'installations' when role == 'Warehouse' || role == 'Admin':
          add(
            _buildAsyncList(
              _getUpcomingBookings(),
              loc.tr('Projects to Install'),
              isDark,
              AppColors.secondary,
              isPickup: true,
            ),
          );
        case 'removals' when role == 'Warehouse' || role == 'Admin':
          add(
            _buildAsyncList(
              _getReturningBookings(),
              loc.tr('Projects to Remove'),
              isDark,
              AppColors.primary,
              isPickup: false,
            ),
          );
        case 'quick_actions':
          add(
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              (isDark ? Colors.white70 : Colors.black54),
                              (isDark ? Colors.white : Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      loc.tr("Quick Actions"),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.transparent,
                              (isDark ? Colors.white70 : Colors.black54),
                              (isDark ? Colors.white : Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ..._buildSelectedQuickActions(role, isDark),
              ],
            ),
          );
      }
    }
    return Column(children: [...sections, const SizedBox(height: 120)]);
  }

  List<Widget> _buildSelectedQuickActions(String role, bool isDark) {
    final canManage = role == 'Admin' || role == 'Owner';
    final widgets = <Widget>[];
    var actionCount = 0;
    int nextActionStyle() => actionCount++ % 3;
    void add(Widget widget) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 14));
      widgets.add(widget);
    }

    for (final action in _dashboardActions) {
      switch (action) {
        case 'add_project' when canManage:
          add(
            _dashboardAction(
              'Add Project',
              'Create a new project',
              AppIcons.booking,
              isDark,
              null,
              navIndex: 4,
              actionStyle: nextActionStyle(),
            ),
          );
        case 'add_client' when canManage:
          add(
            _dashboardAction(
              'Add Client',
              'Add a client to your database',
              AppIcons.userAdd,
              isDark,
              null,
              navIndex: 5,
              actionStyle: nextActionStyle(),
            ),
          );
        case 'add_product' when canManage:
          add(
            _dashboardAction(
              'Add Product',
              'Add an item to inventory',
              AppIcons.add,
              isDark,
              null,
              navIndex: 6,
              actionStyle: nextActionStyle(),
            ),
          );
        case 'view_projects':
          add(
            _dashboardAction(
              'View Projects',
              'Open all projects',
              AppIcons.booking,
              isDark,
              null,
              navIndex: 2,
              actionStyle: nextActionStyle(),
            ),
          );
        case 'inventory':
          add(
            _dashboardAction(
              'Inventory',
              'Browse products and availability',
              AppIcons.inventory,
              isDark,
              InventoryPage(),
              actionStyle: nextActionStyle(),
            ),
          );
        case 'clients' when canManage:
          add(
            _dashboardAction(
              'Clients',
              'Open the client directory',
              AppIcons.client,
              isDark,
              ClientsPage(),
              actionStyle: nextActionStyle(),
            ),
          );
        case 'employees' when canManage:
          add(
            _dashboardAction(
              'Employees',
              'Manage your team',
              AppIcons.userSearch,
              isDark,
              UsersPage(),
              actionStyle: nextActionStyle(),
            ),
          );
        case 'calendar':
          add(
            _dashboardAction(
              'Calendar',
              'View the project calendar',
              AppIcons.calendar,
              isDark,
              const CalendarPage(),
              actionStyle: nextActionStyle(),
            ),
          );
        case 'messages':
          add(
            _dashboardAction(
              'Messages',
              'Open team conversations',
              AppIcons.messages,
              isDark,
              null,
              navIndex: 1,
              actionStyle: nextActionStyle(),
            ),
          );
        case 'test_notification':
          add(
            _buildActionButton(
              title: 'Test Notification',
              subtitle: 'Check that notifications are working',
              imagePath: AppIcons.notification,
              actionStyle: nextActionStyle(),
              color: isDark ? AppColors.primary : AppColors.secondary,
              isDark: isDark,
              onTap: () => _notificationService.showNotification(
                id: 1,
                title: 'Site Lapse',
                body: 'Notification triggered successfully',
              ),
            ),
          );
      }
    }
    if (widgets.isEmpty) {
      widgets.add(
        Text(
          'No quick actions selected. Choose some in Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
      );
    }
    return widgets;
  }

  Widget _dashboardAction(
    String title,
    String subtitle,
    String imagePath,
    bool isDark,
    Widget? route, {
    int? navIndex,
    required int actionStyle,
  }) => _buildActionButton(
    title: title,
    subtitle: subtitle,
    imagePath: imagePath,
    actionStyle: actionStyle,
    color: isDark ? AppColors.primary : AppColors.secondary,
    isDark: isDark,
    onTap: () {
      if (navIndex != null) {
        Provider.of<NavbarProvider>(context, listen: false).setIndex(navIndex);
        return;
      }
      if (route != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => route));
      }
    },
  );

  Widget _buildOwnerStatsView(bool isDark) {
    final loc = AppLocalizations.of(context);
    return FutureBuilder<Map<String, int>>(
      future: _getOwnerStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {
              'activeProjects': 0,
              'projectsToInstall': 0,
              'projectsToRemove': 0,
              'clients': 0,
              'employees': 0,
              'products': 0,
            };
        Color accent = isDark ? AppColors.primary : AppColors.secondary;
        return Column(
          children: [
            Row(
              children: [
                _buildStatCard(
                  loc.tr("Clients"),
                  "${stats['clients']}",
                  null,
                  AppIcons.client,
                  accent,
                  isDark,
                  route: ClientsPage(),
                  dialogAction: () => _showDetailsDialog(
                    loc.tr("All Clients"),
                    supabase.from('clients').select(),
                    isDark,
                  ),
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  loc.tr("Employees"),
                  "${stats['employees']}",
                  null,
                  AppIcons.userSearch,
                  accent,
                  isDark,
                  route: UsersPage(),
                  dialogAction: () => _showDetailsDialog(
                    loc.tr("All Employees"),
                    supabase.from('users').select(),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildStatCard(
                  loc.tr("Products"),
                  "${stats['products']}",
                  null,
                  AppIcons.inventory,
                  accent,
                  isDark,
                  route: InventoryPage(),
                  dialogAction: () => _showDetailsDialog(
                    loc.tr("All Products"),
                    supabase.from('products').select(),
                    isDark,
                  ),
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  loc.tr("Active Projects"),
                  "${stats['activeProjects']}",
                  null,
                  AppIcons.booking,
                  accent,
                  isDark,
                  route: const BookingsPage(showPfp: false),
                  dialogAction: () {
                    final now = DateTime.now().toIso8601String();
                    _showDetailsDialog(
                      loc.tr("Active Projects"),
                      supabase
                          .from('bookings')
                          .select()
                          .neq('status', 'canceled')
                          .neq('status', 'cancelled')
                          .neq('status', 'deleted')
                          .lte('pickup_datetime', now)
                          .gte('return_datetime', now),
                      isDark,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildStatCard(
                  loc.tr("To Install"),
                  "${stats['projectsToInstall']}",
                  null,
                  AppIcons.returns,
                  accent,
                  isDark,
                  route: const BookingsPage(showPfp: false),
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  loc.tr("To Remove"),
                  "${stats['projectsToRemove']}",
                  null,
                  AppIcons.pickUp,
                  accent,
                  isDark,
                  mirrorIcon: true,
                  route: const BookingsPage(showPfp: false),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAsyncList(
    Future<List<Map<String, dynamic>>> future,
    String title,
    bool isDark,
    Color statusColor, {
    bool isPickup = true,
  }) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CustomLoader());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    isPickup
                        ? loc.tr("No projects to install today")
                        : loc.tr("No projects to remove today"),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final data = snapshot.data![index];
                return GestureDetector(
                  onTap: () => _showBookingDetails(
                    data,
                    isDark,
                    isFromActionSection: true,
                    isPickup: isPickup,
                    width: 500,
                  ),
                  child: Card(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      title: Text(
                        data['client_name'] ?? "Unknown Client",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData? icon,
    String? imagePath,
    Color color,
    bool isDark, {
    bool isFullWidth = false,
    bool mirrorIcon = false,
    Widget? route,
    VoidCallback? dialogAction,
  }) {
    Widget card = GestureDetector(
      onTap: () => _handleStatsTap(route: route, dialogAction: dialogAction),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x962C2C2C) : const Color(0x95FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconHelper(imagePath, icon, color),
            const SizedBox(height: 8),
            SlidingNumber(
              value: value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: card)
        : Expanded(child: card);
  }

  Widget _buildIconHelper(String? imagePath, IconData? icon, Color color) {
    if (imagePath != null && imagePath.endsWith('.svg')) {
      return SvgPicture.asset(
        imagePath,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        height: 32,
        width: 32,
      );
    } else if (icon != null) {
      return Icon(icon, color: color, size: 32);
    }
    return const SizedBox(height: 32, width: 32);
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    String? imagePath,
    IconData? icon,
    int actionStyle = 2,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isFilled = actionStyle < 2;
    final fillColor = actionStyle == 0
        ? AppColors.primary
        : AppColors.secondary;
    const outlineColor = AppColors.primary;
    final contentColor = isFilled ? Colors.white : outlineColor;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isFilled ? fillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isFilled
              ? Border.all(color: Colors.transparent)
              : Border.all(color: outlineColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          overlayColor: WidgetStateProperty.all(
            isFilled
                ? Colors.white.withValues(alpha: 0.08)
                : outlineColor.withValues(alpha: 0.05),
          ),
          splashColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: IconHandler.buildIcon(
                      imagePath: imagePath,
                      icon: icon,
                      color: contentColor,
                      size: 35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: contentColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: contentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
