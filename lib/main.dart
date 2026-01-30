// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'core/imports.dart';
import 'firebase_options.dart';

class AppVersion {
  static const String version = "1.0.0";
}

class IconHandler {
  static Widget buildIcon({
    String? imagePath,
    IconData? icon,
    required Color color,
    double size = 24,
    bool isAdd = false,
  }) {
    final double finalSize = isAdd ? 24 : size;
    if (imagePath != null) {
      if (imagePath.toLowerCase().contains('.svg')) {
        return SvgPicture.asset(
          imagePath,
          width: finalSize,
          height: finalSize,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      } else {
        return Image.asset(
          imagePath,
          width: finalSize,
          height: finalSize,
          color: color,
        );
      }
    }
    return Icon(icon, color: color, size: finalSize);
  }
}

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

  await Supabase.initialize(
    url: SupbaseService.url,
    anonKey: SupbaseService.annonKey,
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  await NotificationService().initNotification();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
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

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  OverlayEntry? _networkOverlayEntry;
  bool _isShowingError = false;
  RealtimeChannel? _realtimeChannel;

  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _initConnectivity();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _checkStatus(result);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );

      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final sessionUser = event.session?.user;
        if (sessionUser != null) {
          userProvider.refreshUser();
          bookingProvider.fetchAllBookings();
          _setupSupabaseListener();
          NotificationService().getAndSaveToken();
        } else {
          userProvider.clearUser();
          bookingProvider.clearBookings();
          _stopSupabaseListener();
        }
      });
    });
  }

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

            Provider.of<BookingProvider>(
              context,
              listen: false,
            ).fetchAllBookings();

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
      builder: (context) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.elasticOut,
              ),
            ),
        child: Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          width: MediaQuery.of(context).size.width,
          child: const Material(
            color: Colors.transparent,
            child: NoInternetWidget(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_networkOverlayEntry!);
    _slideController.forward();
  }

  void _hideNoInternetOverlay() async {
    if (!_isShowingError) return;
    _isShowingError = false;
    await _slideController.reverse();
    _networkOverlayEntry?.remove();
    _networkOverlayEntry = null;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _stopSupabaseListener();
    _hideNoInternetOverlay();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // GLOBAL STATUS BAR CONTROL
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark
            ? AppColors.darkbg
            : AppColors.lightcolor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const MainStackHandler(),
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/home': (_) => const CustomNavbar(),
        },
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          brightness: Brightness.light,
          // We set systemOverlayStyle to null in the theme to prevent
          // AppBars in other files from overriding our global setting.
          appBarTheme: const AppBarTheme(systemOverlayStyle: null),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          appBarTheme: const AppBarTheme(systemOverlayStyle: null),
        ),
      ),
    );
  }
}

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
      Future.delayed(const Duration(seconds: 1)),
    ]);

    if (mounted) {
      setState(() {
        _isDataReady = true;
      });

      await _controller.forward();
      widget.onAnimationComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _isDataReady ? _opacityAnimation.value : 1.0,
          child: Container(
            color: isDark ? AppColors.darkbg : AppColors.lightcolor,
            child: Center(
              child: Transform.scale(
                scale: _isDataReady ? _scaleAnimation.value : 1.0,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _isDataReady ? _cropAnimation.value : 1.0,
                    child: Image.asset("assets/logo.png", width: 400),
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
