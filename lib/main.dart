// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Internal Project Imports
import 'firebase_options.dart';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/root.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/login_page.dart';
import 'package:ccr_booking/pages/register_page.dart';
import 'package:ccr_booking/services/notification_service.dart';
import 'package:ccr_booking/services/supbase_service.dart';
import 'package:ccr_booking/widgets/custom_internet_notification.dart';
import 'package:ccr_booking/widgets/custom_navbar.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupbaseService.url,
    anonKey: SupbaseService.annonKey,
  );

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. REGISTER BACKGROUND HANDLER
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // Initialize notification service and setup foreground listeners
  await NotificationService().initNotification();

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
  OverlayEntry? _networkOverlayEntry;
  bool _isShowingError = false;
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
          _setupSupabaseListener();
          // Force token refresh on login
          NotificationService().getAndSaveToken();
        } else {
          userProvider.clearUser();
          _stopSupabaseListener();
        }
      });
    });
  }

  /// 3. SUPABASE REALTIME LISTENER
  /// This handles local notifications when data changes in the DB
  void _setupSupabaseListener() {
    final supabase = Supabase.instance.client;
    if (_realtimeChannel != null) return;

    _realtimeChannel = supabase
        .channel('public:bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final eventType = payload.eventType.name.toUpperCase();

            String title = "Booking $eventType";
            String body =
                "Changes detected in booking for ${newRecord['client_name'] ?? 'Unknown Client'}";

            if (payload.eventType == PostgresChangeEvent.insert) {
              title = "New Booking Created! 📅";
            } else if (payload.eventType == PostgresChangeEvent.update) {
              title = "Booking Updated 🔄";
              body = "Booking status is now: ${newRecord['status']}";
            }

            NotificationService().showNotification(
              id: DateTime.now().millisecond % 100000,
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

  // Connectivity and Overlay Logic...
  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _checkStatus(result);
  }

  void _checkStatus(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      _showNoInternetOverlay();
    } else {
      _hideNoInternetOverlay();
    }
  }

  void _showNoInternetOverlay() {
    if (_isShowingError) return;
    _isShowingError = true;
    _networkOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 15,
        right: 15,
        child: const Material(
          color: Colors.transparent,
          child: NoInternetWidget(),
        ),
      ),
    );
    Overlay.of(context).insert(_networkOverlayEntry!);
  }

  void _hideNoInternetOverlay() {
    if (!_isShowingError) return;
    _isShowingError = false;
    _networkOverlayEntry?.remove();
    _networkOverlayEntry = null;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _stopSupabaseListener();
    _hideNoInternetOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MainStackHandler(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const CustomNavbar(),
      },
      themeMode: ThemeMode.system, // Automatically switches based on phone settings
      theme: ThemeData(
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness:
                Brightness.dark, // Dark icons for light theme
            statusBarBrightness: Brightness.light, // For iOS
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness:
                Brightness.light, // White icons for dark theme
            statusBarBrightness: Brightness.dark, // For iOS
          ),
        ),
      ),
    );
  }
}

// SplashOverlay and MainStackHandler classes remain as they were...
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
