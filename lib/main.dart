// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'core/imports.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

// 1. Define a Global Key for the Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class IconHandler {
  static Widget buildIcon({
    String? imagePath,
    IconData? icon,
    required Color color,
    double size = 24,
    bool isAdd = false,
  }) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.toLowerCase().contains('.svg')) {
        return SvgPicture.asset(
          imagePath,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          // THIS PREVENTS THE CRASH:
          placeholderBuilder: (context) =>
              Icon(icon ?? Icons.broken_image, color: color, size: size),
        );
      } else {
        return Image.asset(
          imagePath,
          width: size,
          height: size,
          color: color,
          // FALLBACK FOR REGULAR IMAGES:
          errorBuilder: (context, error, stackTrace) =>
              Icon(icon ?? Icons.broken_image, color: color, size: size),
        );
      }
    }
    return Icon(icon ?? Icons.help_outline, color: color, size: size);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => NavbarProvider()),
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
      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (!mounted) return;

        // Use the global navigatorKey context to access providers if needed
        final context = navigatorKey.currentContext;
        if (context == null) return;

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final bookingProvider = Provider.of<BookingProvider>(
          context,
          listen: false,
        );

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
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final supabase = Supabase.instance.client;
    if (_realtimeChannel != null) return;

    _realtimeChannel = supabase
        .channel('public:bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) async {
            if (!mounted) return;

            Provider.of<BookingProvider>(
              context,
              listen: false,
            ).fetchAllBookings();

            final newRecord = payload.newRecord;
            String title = "Booking Update";
            String body = "Changes detected in your bookings.";

            if (payload.eventType == PostgresChangeEvent.insert) {
              title = "Booking Created";
              body = "New booking for ${newRecord['client_name'] ?? 'Client'}";
            } else if (payload.eventType == PostgresChangeEvent.update) {
              title = "Booking Updated";
              body = "Booking status: ${newRecord['status']}";
            }

            if (await NotificationService.isEnabled()) {
              NotificationService().showNotification(
                id: DateTime.now().millisecond % 100000,
                title: title,
                body: body,
              );
            }
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

    // Use navigatorKey to find the correct Overlay context
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _isShowingError = true;

    _networkOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _slideController,
                  curve: Curves.easeOutBack,
                ),
              ),
          child: const Material(
            color: Colors.transparent,
            child: SafeArea(child: NoInternetWidget()),
          ),
        ),
      ),
    );

    overlayState.insert(_networkOverlayEntry!);
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
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isDark = themeProvider.isDarkMode;

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
        navigatorKey: navigatorKey, // 2. Pass the key here
        debugShowCheckedModeBanner: false,
        home: const MainStackHandler(),
        locale: localeProvider.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/home': (_) => CustomNavbar(),
        },
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(systemOverlayStyle: null),
          fontFamily: GoogleFonts.poppins().fontFamily,
          textTheme: GoogleFonts.poppinsTextTheme(),
          primaryTextTheme: GoogleFonts.poppinsTextTheme(),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          appBarTheme: const AppBarTheme(systemOverlayStyle: null),
          fontFamily: GoogleFonts.poppins().fontFamily,
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          ),
          primaryTextTheme: GoogleFonts.poppinsTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            },
          ),
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
    return Scaffold(
      body: Stack(
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
      ),
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
      setState(() => _isDataReady = true);
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
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
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
                    child: Image.asset(AppImages.logo, width: 400),
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
