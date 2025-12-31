// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/app_theme.dart';
import '../widgets/custom_pfp.dart';
import '../widgets/custom_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _startRealtimeListener(),
    );
  }

  void _startRealtimeListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _notificationChannel = supabase
        .channel('booking-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_notificationChannel != null)
      supabase.removeChannel(_notificationChannel!);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getUpcomingBookings() async {
    final response = await supabase
        .from('bookings')
        .select()
        .eq('status', 'upcoming')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getReturningBookings() async {
    final response = await supabase
        .from('bookings')
        .select()
        .eq('status', 'returning')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> _getOwnerStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    // Fixed manual count logic to avoid SDK version errors
    final bookingsData = await supabase
        .from('bookings')
        .select('id')
        .gte('created_at', todayStart);
    final clientsData = await supabase.from('clients').select('id');

    return {
      'bookings': (bookingsData as List).length,
      'clients': (clientsData as List).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null)
      return const Scaffold(body: Center(child: CustomLoader()));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: _buildAppBar(currentUser),
      body: RefreshIndicator(
        onRefresh: () async {
          await userProvider.refreshUser();
          if (mounted) setState(() {});
        },
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildRoleDashboard(currentUser.role, isDark),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic currentUser) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
        child: AppBar(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.lightcolor,
          toolbarHeight: 80,
          centerTitle: false,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: AppColors.lightcolor.withOpacity(0.8),
                  fontSize: 18,
                ),
              ),
            ],
          ),
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: CustomPfp(dimentions: 60, fontSize: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDashboard(String role, bool isDark) {
    if (role == 'Warehouse' || role == 'Admin') {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildAsyncList(
              _getUpcomingBookings(),
              "Upcoming Bookings",
              isDark,
              Colors.blue,
            ),
            const SizedBox(height: 30),
            _buildAsyncList(
              _getReturningBookings(),
              "Returning Bookings",
              isDark,
              Colors.orange,
            ),
          ],
        ),
      );
    }
    return _buildOwnerStatsView(isDark);
  }

  Widget _buildAsyncList(
    Future<List<Map<String, dynamic>>> future,
    String title,
    bool isDark,
    Color statusColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title, isDark),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CustomLoader());
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No bookings found."),
                ),
              );
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final data = snapshot.data![index];
                return _buildBookingCard(
                  title: "Client ID: ${data['client_id']}",
                  subtitle: "Ref: ${data['id'].toString().substring(0, 8)}",
                  status: data['status'].toString().toUpperCase(),
                  statusColor: statusColor,
                  isDark: isDark,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildOwnerStatsView(bool isDark) {
    return FutureBuilder<Map<String, int>>(
      future: _getOwnerStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CustomLoader());
        final stats = snapshot.data ?? {'bookings': 0, 'clients': 0};
        return Row(
          children: [
            _buildStatCard(
              "Total Clients",
              "${stats['clients']}",
              Icons.people,
              AppColors.primary,
              isDark,
            ),
            const SizedBox(width: 15),
            _buildStatCard(
              "Today's Bookings",
              "${stats['bookings']}",
              Icons.calendar_today,
              AppColors.secondary,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black,
      ),
    ),
  );

  Widget _buildBookingCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          status,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
