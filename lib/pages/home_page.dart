// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/add/add_booking.dart';
import 'package:ccr_booking/services/notification_service.dart';
import 'package:ccr_booking/widgets/custom_bg_svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../widgets/custom_pfp.dart';
import '../widgets/custom_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  RealtimeChannel? _statsChannel;
  bool _hasConnection = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _initConnectivity();
    _setupRealtimeListeners();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      _checkStatus(result);
    });
  }

  void _setupRealtimeListeners() {
    _statsChannel = supabase
        .channel('public:stats-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) => setState(() {}),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clients',
          callback: (payload) => setState(() {}),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) => setState(() {}),
        )
        .subscribe();
  }

  Future<void> _setupNotifications() async {
    await _notificationService.initNotification();
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
    if (_statsChannel != null) supabase.removeChannel(_statsChannel!);
    super.dispose();
  }

  // --- HELPERS ---

  Map<String, String> _getTodayRange() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      0,
      0,
    ).toIso8601String();
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();
    return {'start': start, 'end': end};
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return "N/A";
    final date = DateTime.parse(isoString);
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }

  // --- NOTIFICATION BROADCAST ---

  Future<void> _notifyAdminsAndOwners(String title, String body) async {
    try {
      // Fetch users with roles Admin or Owner
      final response = await supabase
          .from('users')
          .select('id')
          .or('role.eq.Admin,role.eq.Owner');

      final List adminOwnerIds = response as List;

      // In a real production app with FCM, you would send to these specific IDs.
      // For this local simulation, we trigger the notification to show it works.
      if (adminOwnerIds.isNotEmpty) {
        _notificationService.showNotification(
          id: DateTime.now().millisecond,
          title: title,
          body: body,
        );
      }
    } catch (e) {
      debugPrint("Error notifying admins: $e");
    }
  }

  // --- DATA FETCHING ---

  Future<List<Map<String, dynamic>>> _getUpcomingBookings() async {
    final range = _getTodayRange();
    // Explicitly select all columns including 'products'
    final response = await supabase
        .from('bookings')
        .select('*')
        .eq('status', 'upcoming')
        .gte('pickup_datetime', range['start']!)
        .lte('pickup_datetime', range['end']!)
        .order('pickup_datetime', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getReturningBookings() async {
    final range = _getTodayRange();
    final response = await supabase
        .from('bookings')
        .select('*')
        .eq('status', 'returning')
        .gte('return_datetime', range['start']!)
        .lte('return_datetime', range['end']!)
        .order('return_datetime', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> _getOwnerStats() async {
    try {
      final range = _getTodayRange();
      final pickups = await supabase
          .from('bookings')
          .select('id')
          .gte('pickup_datetime', range['start']!)
          .lte('pickup_datetime', range['end']!);
      final returns = await supabase
          .from('bookings')
          .select('id')
          .gte('return_datetime', range['start']!)
          .lte('return_datetime', range['end']!);
      final clients = await supabase.from('clients').select('id');
      final employees = await supabase.from('users').select('id');
      final products = await supabase.from('products').select('id');

      return {
        'pickups': (pickups as List).length,
        'returns': (returns as List).length,
        'clients': (clients as List).length,
        'employees': (employees as List).length,
        'products': (products as List).length,
      };
    } catch (e) {
      return {
        'pickups': 0,
        'returns': 0,
        'clients': 0,
        'employees': 0,
        'products': 0,
      };
    }
  }

  // --- DIALOGS ---

  void _showBookingDetails(
    Map<String, dynamic> data,
    bool isDark, {
    required bool isFromActionSection,
    bool isPickup = true,
    double width = 500,
  }) {
    // Parse products from DB
    List<String> productList = [];
    var productsRaw = data['products'];

    if (productsRaw is String && productsRaw.isNotEmpty) {
      productList = productsRaw.split(',').map((e) => e.trim()).toList();
    } else if (productsRaw is List) {
      productList = List<String>.from(productsRaw);
    }

    if (productList.isEmpty) productList = ["No products found in database"];

    Map<String, bool> checkedItems = {for (var p in productList) p: false};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Booking Details",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPopupField(
                        "Client",
                        data['client_name'] ?? "Unknown",
                        isDark,
                      ),
                      _buildPopupField(
                        "Pickup",
                        _formatDateTime(data['pickup_datetime']),
                        isDark,
                        icon: Icons.upload_rounded,
                      ),
                      _buildPopupField(
                        "Return",
                        _formatDateTime(data['return_datetime']),
                        isDark,
                        icon: Icons.download_rounded,
                      ),
                      const Divider(height: 30),
                      const Text(
                        "Products",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...productList.map(
                        (product) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            product,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          value: checkedItems[product] ?? false,
                          onChanged: (val) {
                            setDialogState(() {
                              checkedItems[product] = val ?? false;
                            });
                          },
                          activeColor: AppColors.primary,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                if (isFromActionSection)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPickup
                          ? AppColors.secondary
                          : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      String newStatus = isPickup ? 'returning' : 'completed';
                      await supabase
                          .from('bookings')
                          .update({'status': newStatus})
                          .eq('id', data['id']);

                      // Notify all Admins and Owners
                      await _notifyAdminsAndOwners(
                        isPickup ? "Pickup Confirmed" : "Return Confirmed",
                        "${data['client_name']} has ${isPickup ? 'picked up' : 'returned'} items.",
                      );

                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: Text(
                      isPickup ? "Mark as Picked Up" : "Mark as Returned",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDetailsDialog(String title, Future future, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CustomLoader()),
                );
              }
              if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No data found.", textAlign: TextAlign.center),
                );
              }

              final list = snapshot.data as List<Map<String, dynamic>>;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  String mainText =
                      item['name'] ??
                      item['client_name'] ??
                      "ID: ${item['id']}";
                  String subText =
                      item['email'] ?? item['status'] ?? "Entry #$index";
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      mainText,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      subText,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        mainText[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null)
      return const Scaffold(body: Center(child: CustomLoader()));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      body: Stack(
        children: [
          const CustomBgSvg(),
          Column(
            children: [
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: _buildAppBar(currentUser),
              ),
              if (!_hasConnection) _buildConnectionError(),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () async {
                        await userProvider.refreshUser();
                        if (mounted) setState(() {});
                      },
                      builder:
                          (
                            context,
                            refreshState,
                            pulledExtent,
                            triggerDistance,
                            indicatorExtent,
                          ) => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CustomLoader(size: 24),
                            ),
                          ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(20.0),
                      sliver: SliverToBoxAdapter(
                        child: _buildRoleDashboard(currentUser.role, isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(dynamic currentUser) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
      child: Container(
        padding: EdgeInsets.only(top: statusBarHeight),
        color: AppColors.secondary,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.lightcolor,
          toolbarHeight: 80,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hello, ${currentUser.name.split(' ').first}',
                style: AppFontStyle.subTitleMedium().copyWith(
                  color: AppColors.lightcolor,
                ),
              ),
              Text(
                "Manage everything in a few clicks",
                style: AppFontStyle.textRegular().copyWith(
                  fontSize: 18,
                  color: AppColors.lightcolor,
                ),
              ),
            ],
          ),
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: Center(child: CustomPfp(dimentions: 60, fontSize: 24)),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDashboard(String role, bool isDark) {
    return Column(
      children: [
        if (role == 'Warehouse' || role == 'Admin') ...[
          _buildAsyncList(
            _getUpcomingBookings(),
            "Today's Pickups",
            isDark,
            AppColors.secondary,
            isPickup: true,
          ),
          const SizedBox(height: 30),
          _buildAsyncList(
            _getReturningBookings(),
            "Today's Returns",
            isDark,
            AppColors.primary,
            isPickup: false,
          ),
          const SizedBox(height: 30),
        ] else if (role == 'Owner') ...[
          _buildOwnerStatsView(isDark),
          const SizedBox(height: 30),
        ],
        if (role == 'Admin' || role == 'Owner') ...[
          _buildActionButton(
            title: "Create New Booking",
            subtitle: "Start a fresh equipment rental",
            icon: Icons.add_circle_outline,
            color: AppColors.primary,
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddBooking()),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _buildActionButton(
          title: "Recieve a notification",
          subtitle: "Test the notification system",
          icon: Icons.notifications_on_rounded,
          color: AppColors.secondary,
          isDark: isDark,
          onTap: () => _notificationService.showNotification(
            id: 1,
            title: "CCR Booking",
            body: "This is a testing notification",
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOwnerStatsView(bool isDark) {
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
                  "Clients",
                  "${stats['clients']}",
                  Icons.people,
                  accent,
                  isDark,
                  onTap: () => _showDetailsDialog(
                    "All Clients",
                    supabase.from('clients').select(),
                    isDark,
                  ),
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  "Employees",
                  "${stats['employees']}",
                  Icons.badge,
                  accent,
                  isDark,
                  onTap: () => _showDetailsDialog(
                    "All Employees",
                    supabase.from('users').select(),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildStatCard(
              "Products",
              "${stats['products']}",
              Icons.inventory_2,
              accent,
              isDark,
              isFullWidth: true,
              onTap: () => _showDetailsDialog(
                "All Products",
                supabase.from('products').select(),
                isDark,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildStatCard(
                  "Today's Pickups",
                  "${stats['pickups']}",
                  Icons.calendar_today,
                  accent,
                  isDark,
                  onTap: () {
                    final range = _getTodayRange();
                    _showDetailsDialog(
                      "Today's Pickups",
                      supabase
                          .from('bookings')
                          .select()
                          .gte('pickup_datetime', range['start']!)
                          .lte('pickup_datetime', range['end']!),
                      isDark,
                    );
                  },
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  "Today's Returns",
                  "${stats['returns']}",
                  Icons.assignment_return,
                  accent,
                  isDark,
                  onTap: () {
                    final range = _getTodayRange();
                    _showDetailsDialog(
                      "Today's Returns",
                      supabase
                          .from('bookings')
                          .select()
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
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CustomLoader());
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No bookings for today."),
                ),
              );
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
    IconData icon,
    Color color,
    bool isDark, {
    bool isFullWidth = false,
    VoidCallback? onTap,
  }) {
    Widget card = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x962C2C2C) : const Color(0x95FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            SlidingNumber(
              value: value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionError() {
    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.all(8),
      child: const Text(
        "No Internet Connection",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class SlidingNumber extends StatelessWidget {
  final String value;
  final TextStyle style;
  const SlidingNumber({super.key, required this.value, required this.style});
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.5),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(value, key: ValueKey<String>(value), style: style),
    );
  }
}
