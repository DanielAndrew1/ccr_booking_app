// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../core/imports.dart';

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

  String _getEmptyDialogMessage(String title) {
    final t = title.toLowerCase();

    if (t.contains('pickup')) return "No pickups for today";
    if (t.contains('return')) return "No returns for today";
    if (t.contains('product')) return "No products found";
    if (t.contains('client')) return "No clients found";
    if (t.contains('employee') || t.contains('user')) {
      return "No employees found";
    }

    return "No data available";
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

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

  Future<void> _notifyAdminsAndOwners(String title, String body) async {
    try {
      final response = await supabase
          .from('users')
          .select('id')
          .or('role.eq.Admin,role.eq.Owner');

      final List adminOwnerIds = response as List;

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
    final response = await supabase
        .from('bookings')
        .select('*')
        .eq('status', 'upcoming')
        .neq('status', 'canceled')
        .neq('status', 'deleted')
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
        .neq('status', 'canceled')
        .neq('status', 'deleted')
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
          .neq('status', 'canceled')
          .neq('status', 'deleted')
          .gte('pickup_datetime', range['start']!)
          .lte('pickup_datetime', range['end']!);
      final returns = await supabase
          .from('bookings')
          .select('id')
          .neq('status', 'canceled')
          .neq('status', 'deleted')
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
                      String newStatus = isPickup ? 'Returning' : 'Completed';
                      await supabase
                          .from('bookings')
                          .update({'status': newStatus})
                          .eq('id', data['id']);

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
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _getEmptyDialogMessage(title),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
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

                  bool isProduct = title.toLowerCase().contains("product");
                  String? imageUrl = item['image_url'];

                  Widget subtitleWidget;
                  if (isProduct && item['price'] != null) {
                    subtitleWidget = Text(
                      "${item['price']} EGP/Day",
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  } else {
                    subtitleWidget = Text(
                      item['email'] ?? item['status'] ?? "Entry #$index",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    );
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      mainText,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: subtitleWidget,
                    leading: isProduct && imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 45,
                              height: 45,
                              color: AppColors.primary.withOpacity(0.1),
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                          )
                        : CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(
                              _getInitials(mainText),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
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
                if (!_hasConnection) NoInternetWidget(),
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
            child: Center(child: CustomPfp(dimentions: 65, fontSize: 21)),
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
          const SizedBox(height: 22),
        ],
        Row(
          children: [
            const Expanded(
              child: Divider(
                thickness: 1,
                // Optional: match your theme colors
                color: Colors.grey,
                endIndent: 10, // Adds a small gap before the text
              ),
            ),
            Text(
              "Quick Actions",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const Expanded(
              child: Divider(
                thickness: 1,
                color: Colors.grey,
                indent: 10, // Adds a small gap after the text
              ),
            ),
          ],
        ),
        SizedBox(height: 22),
        if (role == 'Admin' || role == 'Owner') ...[
          _buildActionButton(
            title: "Add New Client",
            subtitle: "Add a new client to your database",
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
          title: "Recieve a notification",
          subtitle: "Test the notification system",
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
                  null,
                  AppIcons.client,
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
                  null,
                  AppIcons.userSearch,
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
              null,
              AppIcons.inventory,
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
                  null,
                  AppIcons.pickUp,
                  accent,
                  isDark,
                  mirrorIcon: true,
                  onTap: () {
                    final range = _getTodayRange();
                    _showDetailsDialog(
                      "Today's Pickups",
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
                  "Today's Returns",
                  "${stats['returns']}",
                  null,
                  AppIcons.returns,
                  accent,
                  isDark,
                  onTap: () {
                    final range = _getTodayRange();
                    _showDetailsDialog(
                      "Today's Returns",
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
                    isPickup ? "No pickups for today." : "No returns for today",
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
            mirrorIcon
                ? Transform.flip(
                    flipX: true,
                    child: _buildIconHelper(imagePath, icon, color),
                  )
                : _buildIconHelper(imagePath, icon, color),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isFilled
                      ? Colors.transparent
                      : (isDark ? AppColors.primary.withOpacity(0) : AppColors.secondary.withOpacity(0)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: IconHandler.buildIcon(
                  imagePath: imagePath,
                  color: isFilled
                      ? (isDark ? AppColors.secondary : AppColors.primary)
                      : (isDark ? AppColors.primary : AppColors.secondary),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 15),
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
                          : (isDark ? Colors.white : Color(0xFF151515)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isFilled
                          ? Colors.white
                          : (isDark ? Colors.white : Color(0xFF151515)),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
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
