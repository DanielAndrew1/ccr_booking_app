// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/root.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/login_page.dart';
import 'package:ccr_booking/pages/register_page.dart';
import 'package:ccr_booking/services/notification_service.dart';
import 'package:ccr_booking/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initNotification();

if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Supabase.initialize(
    url: 'https://jjodrxidqzcreqzteyqa.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqb2RyeGlkcXpjcmVxenRleXFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1NzE2NDQsImV4cCI6MjA4MjE0NzY0NH0.692jVmgqONLClX3zwdOLzgb1ag61e_bnFs-YXwOT9FA',
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;

  // Realtime Channel reference
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();

    _initConnectivity();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _checkStatus(result);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final sessionUser = event.session?.user;
        if (sessionUser != null) {
          userProvider.refreshUser();
          // Start listening to DB changes when user is logged in
          _setupSupabaseListener();
        } else {
          userProvider.clearUser();
          // Stop listening when user logs out
          _stopSupabaseListener();
        }
      });
    });
  }

  /// ============================
  /// SUPABASE REALTIME LISTENER
  /// ============================
  void _setupSupabaseListener() {
    final supabase = Supabase.instance.client;

    // Ensure we don't create multiple channels
    if (_realtimeChannel != null) return;

    _realtimeChannel = supabase
        .channel('public:bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent
              .all, // Listen for Inserts, Updates, and Deletes
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final eventType = payload.eventType.name.toUpperCase();

            // Logic to determine notification content
            String title = "Booking $eventType";
            String body =
                "Changes detected in booking for ${newRecord['client_name'] ?? 'Unknown Client'}";

            if (payload.eventType == PostgresChangeEvent.insert) {
              title = "New Booking Created! 📅";
            } else if (payload.eventType == PostgresChangeEvent.update) {
              title = "Booking Updated 🔄";
              body = "Booking status is now: ${newRecord['status']}";
            }

            // Trigger Local Notification
            NotificationService().showNotification(
              id: DateTime.now().millisecond,
              title: title,
              body: body,
            );
          },
        )
        .subscribe();
  }

  void _stopSupabaseListener() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
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
    _stopSupabaseListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: MyThemes.lightTheme,
      darkTheme: MyThemes.darkTheme,
      home: MainStackHandler(hasConnection: _hasConnection),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const CustomNavbar(),
      },
    );
  }
}

class MainStackHandler extends StatefulWidget {
  final bool hasConnection;
  const MainStackHandler({super.key, required this.hasConnection});

  @override
  State<MainStackHandler> createState() => _MainStackHandlerState();
}

class _MainStackHandlerState extends State<MainStackHandler> {
  bool _isSplashFinished = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // No Internet Connection Widget at the top
            if (!widget.hasConnection && _isSplashFinished)
              const NoInternetWidget(),
            // Main content
            Expanded(child: const RootPage()),
          ],
        ),
        if (!_isSplashFinished)
          SplashOverlay(
            onAnimationComplete: () {
              setState(() {
                _isSplashFinished = true;
              });
            },
          ),
      ],
    );
  }
}

class SplashOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  const SplashOverlay({super.key, required this.onAnimationComplete});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cropAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isDataReady = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _cropAnimation = Tween<double>(begin: 1.0, end: 0.45).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.linear),
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await Future.wait([
      userProvider.loadUser(),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (mounted) {
      setState(() {
        _isDataReady = true;
      });
    }

    await _controller.forward();
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            color: isDark ? AppColors.darkbg : AppColors.lightcolor,
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _cropAnimation.value,
                    child: Image.asset(
                      "assets/logo.png",
                      width: 400,
                      color: _isDataReady ? null : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
