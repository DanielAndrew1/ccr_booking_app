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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => route),
      );
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
    return Column(
      children: [
        if (role == 'Warehouse' || role == 'Admin') ...[
          _buildAsyncList(
            _getUpcomingBookings(),
            loc.tr("Today's Pickups"),
            isDark,
            AppColors.secondary,
            isPickup: true,
          ),
          const SizedBox(height: 30),
          _buildAsyncList(
            _getReturningBookings(),
            loc.tr("Today's Returns"),
            isDark,
            AppColors.primary,
            isPickup: false,
          ),
          const SizedBox(height: 30),
        ] else if (role == 'Owner') ...[
          _buildOwnerStatsView(isDark),
          const SizedBox(height: 22),
        ],
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
        SizedBox(height: 22),
        if (role == 'Admin' || role == 'Owner') ...[
          _buildActionButton(
            title: loc.tr("Add Client"),
            subtitle: loc.tr("Add a new client to your database"),
            imagePath: AppIcons.userAdd,
            isFilled: true,
            color: isDark ? AppColors.primary : AppColors.secondary,
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddClient()),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _buildActionButton(
          title: loc.tr("Recieve a notification"),
          subtitle: loc.tr("Test the notification system"),
          imagePath: AppIcons.notification,
          color: isDark ? AppColors.primary : AppColors.secondary,
          isDark: isDark,
          onTap: () => _notificationService.showNotification(
            id: 1,
            title: "CCR Booking",
            body: "Notification triggered successfully",
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildOwnerStatsView(bool isDark) {
    final loc = AppLocalizations.of(context);
    return FutureBuilder<Map<String, int>>(
      future: _getOwnerStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {
              'pickups': 0,
              'returns': 0,
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
            _buildStatCard(
              loc.tr("Products"),
              "${stats['products']}",
              null,
              AppIcons.inventory,
              accent,
              isDark,
              isFullWidth: true,
              route: InventoryPage(),
              dialogAction: () => _showDetailsDialog(
                loc.tr("All Products"),
                supabase.from('products').select(),
                isDark,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildStatCard(
                  loc.tr("Today's Pickups"),
                  "${stats['pickups']}",
                  null,
                  AppIcons.pickUp,
                  accent,
                  isDark,
                  mirrorIcon: true,
                  route: BookingsPage(),
                  dialogAction: () {
                    final range = _getTodayRange();
                    _showDetailsDialog(
                      loc.tr("Today's Pickups"),
                      supabase
                          .from('bookings')
                          .select()
                          .neq('status', 'canceled')
                          .neq('status', 'deleted')
                          .gte('pickup_datetime', range['start']!)
                          .lte('pickup_datetime', range['end']!),
                      isDark,
                    );
                  },
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  loc.tr("Today's Returns"),
                  "${stats['returns']}",
                  null,
                  AppIcons.returns,
                  accent,
                  isDark,
                  route: BookingsPage(),
                  dialogAction: () {
                    final range = _getTodayRange();
                    _showDetailsDialog(
                      loc.tr("Today's Returns"),
                      supabase
                          .from('bookings')
                          .select()
                          .neq('status', 'canceled')
                          .neq('status', 'deleted')
                          .gte('return_datetime', range['start']!)
                          .lte('return_datetime', range['end']!),
                      isDark,
                    );
                  },
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
                        ? loc.tr("No pickups for today.")
                        : loc.tr("No returns for today"),
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
    bool isFilled = false,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isFilled
              ? (isDark ? AppColors.primary : AppColors.secondary)
              : (isDark ? Colors.transparent : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: isFilled
              ? Border.all(color: Colors.transparent)
              : Border.all(
                  color: isDark ? AppColors.primary : AppColors.secondary,
                ),
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
            isDark
                ? (!isFilled
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.08))
                : (!isFilled
                      ? AppColors.secondary.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.08)),
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
                    color: isFilled ? Colors.transparent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: IconHandler.buildIcon(
                      imagePath: imagePath,
                      color: isFilled
                          ? (isDark ? Colors.white : Colors.white)
                          : (isDark ? AppColors.primary : AppColors.secondary),
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
                          color: isFilled
                              ? Colors.white
                              : (isDark
                                    ? AppColors.primary
                                    : AppColors.secondary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isFilled
                              ? Colors.white
                              : (isDark
                                    ? AppColors.primary
                                    : AppColors.secondary),
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
                  color: isFilled
                      ? Colors.white
                      : (isDark ? AppColors.primary : AppColors.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
