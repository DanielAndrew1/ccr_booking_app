// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_theme.dart';
import '../pages/login_page.dart';
import '../widgets/custom_pfp.dart';
import '../widgets/custom_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  // 1. Warehouse Fetch
  Future<List<Map<String, dynamic>>> _getUpcomingBookings() async {
    final response = await supabase
        .from('bookings')
        .select()
        .eq('status', 'upcoming')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 2. Admin Fetch
  Future<List<Map<String, dynamic>>> _getCompletedBookings() async {
    final response = await supabase
        .from('bookings')
        .select()
        .eq('status', 'completed')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 3. Owner Fetch (Cleanest Syntax for Counting)
  Future<Map<String, int>> _getOwnerStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    // Use .count(CountOption.exact) to get the count property in the response
    final bookingsRes = await supabase
        .from('bookings')
        .select('id')
        .gte('created_at', todayStart)
        .count(CountOption.exact);

    final clientsRes = await supabase
        .from('clients')
        .select('id')
        .count(CountOption.exact);

    return {'bookings': bookingsRes.count, 'clients': clientsRes.count};
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(60),
          ),
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
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildRoleDashboard(currentUser.role, isDark),
        ),
      ),
    );
  }

  Widget _buildRoleDashboard(String role, bool isDark) {
    if (role == 'Warehouse') {
      return _buildAsyncList(
        _getUpcomingBookings(),
        "Upcoming Bookings",
        isDark,
        Colors.blue,
      );
    } else if (role == 'Admin') {
      return _buildAsyncList(
        _getCompletedBookings(),
        "Completed Bookings",
        isDark,
        Colors.green,
      );
    } else if (role == 'Owner') {
      return _buildOwnerStatsView(isDark);
    }
    return const Center(child: Text("Unknown Role"));
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
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(child: CustomLoader());
              if (snapshot.hasError)
                return Center(child: Text("No bookings found."));
              if (!snapshot.hasData || snapshot.data!.isEmpty)
                return const Center(child: Text("No data found."));

              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final data = snapshot.data![index];
                  return _buildBookingCard(
                    title: data['client_name'] ?? "Unknown Client",
                    subtitle:
                        "Ref: ${data['id'].toString().toUpperCase().substring(0, 8)}",
                    status: data['status'].toString().toUpperCase(),
                    statusColor: statusColor,
                    isDark: isDark,
                  );
                },
              );
            },
          ),
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
        if (snapshot.hasError)
          return Center(child: Text("Error loading stats"));

        final stats = snapshot.data ?? {'bookings': 0, 'clients': 0};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Today's Overview", isDark),
            const SizedBox(height: 15),
            Row(
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
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
