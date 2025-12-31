// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/add/add_booking.dart';
import 'package:ccr_booking/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  // Connectivity
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _checkStatus(result);
    });
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    setState(() {
      _hasConnection = !result.contains(ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
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
    try {
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();
      final bookingsData = await supabase
          .from('bookings')
          .select('id')
          .gte('created_at', todayStart);
      final clientsData = await supabase.from('clients').select('id');
      final employeesData = await supabase.from('users').select('id');
      return {
        'bookings': (bookingsData as List).length,
        'clients': (clientsData as List).length,
        'employees': (employeesData as List).length,
      };
    } catch (e) {
      return {'bookings': 0, 'clients': 0, 'employees': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      body: Column(
        children: [
          _buildAppBar(currentUser),
          if (!_hasConnection) const NoInternetWidget(),
          Expanded(
            child: RefreshIndicator(
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
          ),
        ],
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
                  fontSize: 20,
                  color: AppColors.lightcolor.withOpacity(0.8),
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          if (role == 'Warehouse' || role == 'Admin') ...[
            _buildAsyncList(
              _getUpcomingBookings(),
              "Upcoming Bookings",
              isDark,
              AppColors.secondary,
            ),
            const SizedBox(height: 30),
            _buildAsyncList(
              _getReturningBookings(),
              "Returning Bookings",
              isDark,
              AppColors.primary,
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
            _buildActionButton(
              title: "Get a Notification",
              subtitle: "Test the noticication service",
              icon: Icons.notifications_on_rounded,
              color: AppColors.secondary,
              isDark: isDark,
              onTap: () {
                NotificationService().showNotification(
                  title: "CCR Booking App",
                  body: "Testing the notification service",
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildOwnerStatsView(bool isDark) {
    return FutureBuilder<Map<String, int>>(
      future: _getOwnerStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        final stats =
            snapshot.data ?? {'bookings': 0, 'clients': 0, 'employees': 0};
        return Column(
          children: [
            Row(
              children: [
                _buildStatCard(
                  "Total Clients",
                  "${stats['clients']}",
                  Icons.people,
                  isDark ? AppColors.primary : AppColors.secondary,
                  isDark,
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  "Total Employees",
                  "${stats['employees']}",
                  Icons.badge,
                  isDark ? AppColors.primary : AppColors.secondary,
                  isDark,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildStatCard(
                  "Today's Bookings",
                  "${stats['bookings']}",
                  Icons.calendar_today,
                  isDark ? AppColors.primary : AppColors.secondary,
                  isDark,
                ),
              ],
            ),
          ],
        );
      },
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
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No bookings found."),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final data = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  child: ListTile(
                    title: Text("Client ID: ${data['client_id']}"),
                    subtitle: Text(
                      "Ref: ${data['id'].toString().substring(0, 8)}",
                    ),
                    trailing: Text(
                      data['status'].toString().toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
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
          border: Border.all(color: color.withOpacity(0.5), width: 1),
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
}

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B3B),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'No internet connection - Please check your network',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}
