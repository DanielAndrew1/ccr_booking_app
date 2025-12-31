// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/root.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/login_page.dart';
import 'package:ccr_booking/pages/register_page.dart';
import 'package:ccr_booking/services/notification_service.dart';
import 'package:ccr_booking/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // New Import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("20f7abe2-84af-409a-9195-cd36847dc0fa");
  OneSignal.Notifications.requestPermission(true);

  // Initialize local notifications service
  NotificationService().initNotification();

  // Initialize sqflite for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://jjodrxidqzcreqzteyqa.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
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
  // Global key to show the top banner across all screens
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isBannerShowing = false;

  @override
  void initState() {
    super.initState();

    // Check connectivity on startup
    _initConnectivity();

    // Listen for connectivity changes
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
          OneSignal.login(sessionUser.id);
        } else {
          userProvider.clearUser();
          OneSignal.logout();
        }
      });
    });
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      _showNoInternetBanner();
    } else {
      _hideNoInternetBanner();
    }
  }

  void _showNoInternetBanner() {
    if (_isBannerShowing) return;
    _isBannerShowing = true;

    _scaffoldMessengerKey.currentState?.showMaterialBanner(
      MaterialBanner(
        elevation: 0,
        backgroundColor: Colors.redAccent,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        content: const Text(
          'Please connect to a network connection and try again',
          textAlign: TextAlign.center,
        ),
        actions: [
          const SizedBox.shrink(), // Required parameter, but we want it clean
        ],
      ),
    );
  }

  void _hideNoInternetBanner() {
    if (!_isBannerShowing) return;
    _isBannerShowing = false;
    _scaffoldMessengerKey.currentState?.clearMaterialBanners();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      scaffoldMessengerKey:
          _scaffoldMessengerKey, // Essential for global banners
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: MyThemes.lightTheme,
      darkTheme: MyThemes.darkTheme,
      home: const MainStackHandler(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const CustomNavbar(),
      },
    );
  }
}

/// ============================
/// STACK HANDLER
/// ============================
class MainStackHandler extends StatefulWidget {
  const MainStackHandler({super.key});

  @override
  State<MainStackHandler> createState() => _MainStackHandlerState();
}

class _MainStackHandlerState extends State<MainStackHandler> {
  bool _isSplashFinished = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const RootPage(),
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

/// ============================
/// ANIMATED SPLASH OVERLAY
/// ============================
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
                      colorBlendMode: _isDataReady ? null : BlendMode.dst,
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
