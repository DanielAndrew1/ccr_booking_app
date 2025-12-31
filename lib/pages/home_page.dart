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
  final notificationService = NotificationService();
  RealtimeChannel? _notificationChannel;
  bool _isNotificationSending = false;

  // Connectivity
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _initializeNotifications();

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

  Future<void> _initializeNotifications() async {
    try {
      await notificationService.initNotification();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startRealtimeListener(),
      );
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  void _startRealtimeListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      _notificationChannel = supabase
          .channel('booking-updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            callback: (payload) async {
              // Handle real-time updates
              if (mounted) setState(() {});

              // Show notification based on event type
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;

              if (payload.eventType == PostgresChangeEvent.insert) {
                // New booking created
                await notificationService.showBookingCreatedNotification(
                  clientName: newRecord['client_name'] ?? 'Unknown Client',
                  bookingId: newRecord['id']?.toString(),
                );
              } else if (payload.eventType == PostgresChangeEvent.update) {
                // Booking updated
                final oldStatus = oldRecord?['status']?.toString() ?? '';
                final newStatus = newRecord['status']?.toString() ?? '';

                if (oldStatus != newStatus) {
                  // Status changed
                  await notificationService.showBookingStatusNotification(
                    clientName: newRecord['client_name'] ?? 'Unknown Client',
                    oldStatus: oldStatus,
                    newStatus: newStatus,
                    bookingId: newRecord['id']?.toString(),
                  );
                } else {
                  // Other update
                  await notificationService.showBookingUpdatedNotification(
                    clientName: newRecord['client_name'] ?? 'Unknown Client',
                    status: newRecord['status']?.toString() ?? 'Unknown',
                    bookingId: newRecord['id']?.toString(),
                  );
                }
              }
            },
          )
          .subscribe();

      print('✅ Realtime listener started');
    } catch (e) {
      print('❌ Error starting realtime listener: $e');
    }
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      supabase.removeChannel(_notificationChannel!);
    }
    _connectivitySubscription.cancel();
    super.dispose();
  }

  /// Test notification with improved feedback
  Future<void> _showTestNotification() async {
    if (_isNotificationSending) return;

    setState(() => _isNotificationSending = true);

    try {
      // Send the notification
      final success = await notificationService.showNotification(
        title: '✅ Test Successful',
        body: 'Your notification system is working perfectly!',
        payload: 'test_notification',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Notification sent successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Failed to send notification')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error sending test notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNotificationSending = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getUpcomingBookings() async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .eq('status', 'upcoming')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching upcoming bookings: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getReturningBookings() async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .eq('status', 'returning')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching returning bookings: $e');
      return [];
    }
  }

  Future<Map<String, int>> _getOwnerStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      // Get today's bookings
      final bookingsData = await supabase
          .from('bookings')
          .select('id')
          .gte('created_at', todayStart);

      // Get total clients
      final clientsData = await supabase.from('clients').select('id');

      // Get total employees (users)
      final employeesData = await supabase.from('users').select('id');

      return {
        'bookings': (bookingsData as List).length,
        'clients': (clientsData as List).length,
        'employees': (employeesData as List).length,
      };
    } catch (e) {
      print('❌ Error fetching owner stats: $e');
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
          // AppBar
          _buildAppBar(currentUser),

          // No Internet Widget at the top
          if (!_hasConnection) const NoInternetWidget(),

          // Main Content
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          if (role == 'Warehouse' || role == 'Admin') ...[
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
            const SizedBox(height: 30),
          ] else if (role == 'Owner') ...[
            _buildOwnerStatsView(isDark),
            const SizedBox(height: 30),
          ],

          // --- ACTION BUTTONS ---
          // Create New Booking button (Admin and Owner only)
          if (role == 'Admin' || role == 'Owner') ...[
            _buildActionButton(
              title: "Create New Booking",
              subtitle: "Start a fresh equipment rental",
              icon: Icons.add_circle_outline,
              color: AppColors.primary,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddBooking()),
                );
              },
            ),
            const SizedBox(height: 15),
          ],

          // Test Notification button (All roles)
          _buildActionButton(
            title: "Test Notification",
            subtitle: "Send a local test alert",
            icon: _isNotificationSending
                ? Icons.hourglass_empty
                : Icons.notifications_active_outlined,
            color: AppColors.secondary,
            isDark: isDark,
            isLoading: _isNotificationSending,
            onTap: _isNotificationSending ? () {} : _showTestNotification,
          ),
          const SizedBox(height: 40),
        ],
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
        _sectionTitle(title, isDark),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CustomLoader());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading bookings',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              );
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        final stats =
            snapshot.data ?? {'bookings': 0, 'clients': 0, 'employees': 0};
        return Column(
          children: [
            // First Row - Clients and Employees
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
                  "Total Employees",
                  "${stats['employees']}",
                  Icons.badge,
                  Colors.purple,
                  isDark,
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Second Row - Today's Bookings (Full Width)
            _buildStatCard(
              "Today's Bookings",
              "${stats['bookings']}",
              Icons.calendar_today,
              AppColors.secondary,
              isDark,
              isFullWidth: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Opacity(
        opacity: isLoading ? 0.6 : 1.0,
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
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, color: color),
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
      ),
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
    bool isDark, {
    bool isFullWidth = false,
  }) {
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
}

// Custom No Internet Widget
class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B3B), // Bright red color
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
          // Alert Icon
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
          // Text Message
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
          // WiFi Icon
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}
