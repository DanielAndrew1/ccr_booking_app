// ignore_for_file: deprecated_member_use

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notifications
  NotificationService().initNotification();

  // Initialize sqflite for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://jjodrxidqzcreqzteyqa.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqb2RyeGlkcXpjcmVxenRleXFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1NzE2NDQsImV4cCI6MjA4MjE0NzY0NH0.692jVmgqONLClX3zwdOLzgb1ag61e_bnFs-YXwOT9FA',
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final sessionUser = event.session?.user;
        if (sessionUser != null) {
          userProvider.refreshUser();
        } else {
          userProvider.clearUser();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
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
  
  // Track if the background data check is done
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

    // 1. Wait for Auth determination AND a minimum static delay (e.g., 500ms)
    // This prevents the animation from starting instantly and looking "glitchy"
    await Future.wait([
      userProvider.loadUser(),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (mounted) {
      setState(() {
        _isDataReady = true;
      });
    }

    // 2. Now start the visual animation
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
                      // Hide the logo until data is ready to avoid flashing 
                      // before we know where the user is going
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