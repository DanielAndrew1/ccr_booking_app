// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_field, unused_element
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/imports.dart';
part 'home_page_widgets.dart';

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
        .neq('status', 'cancelled')
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
        .neq('status', 'cancelled')
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
          .neq('status', 'cancelled')
          .neq('status', 'deleted')
          .gte('pickup_datetime', range['start']!)
          .lte('pickup_datetime', range['end']!);
      final returns = await supabase
          .from('bookings')
          .select('id')
          .neq('status', 'canceled')
          .neq('status', 'cancelled')
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
    final loc = AppLocalizations.of(context);
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
              title: Text(
                loc.tr("Booking Details"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPopupField(
                        loc.tr("Client"),
                        data['client_name'] ?? "Unknown",
                        isDark,
                      ),
                      _buildPopupField(
                        loc.tr("Pickup"),
                        _formatDateTime(data['pickup_datetime']),
                        isDark,
                        icon: Icons.upload_rounded,
                      ),
                      _buildPopupField(
                        loc.tr("Return"),
                        _formatDateTime(data['return_datetime']),
                        isDark,
                        icon: Icons.download_rounded,
                      ),
                      const Divider(height: 30),
                      Text(
                        loc.tr("Products"),
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
                  child: Text(
                    loc.tr("Close"),
                    style: const TextStyle(color: Colors.grey),
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
                      isPickup
                          ? loc.tr("Mark as Picked Up")
                          : loc.tr("Mark as Returned"),
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

              final rawList = snapshot.data as List<Map<String, dynamic>>;
              final list = rawList.where((item) {
                final status = (item['status'] ?? '').toString().toLowerCase();
                return status != 'canceled' &&
                    status != 'cancelled' &&
                    status != 'deleted';
              }).toList();
              if (list.isEmpty) {
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
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        appBar: CustomAppBar(
          showPfp: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text("Hello, ${currentUser.name.split(" ").first}"),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text("Manage everything in a few clicks", style: TextStyle(fontSize: 16),),
                ],
              ),
            ],
          )
        ),
        body: Stack(
          children: [
            const CustomBgSvg(),
            Padding(
              padding: const EdgeInsets.only(top: 140),
              child: Column(
                children: [
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
            ),
          ],
        ),
      ),
    );
  }

}
