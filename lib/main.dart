// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'core/imports.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

// 1. Define a Global Key for the Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  unawaited(NotificationService().initNotification());

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
  RealtimeChannel? _messagesRealtimeChannel;

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
    _realtimeChannel ??= supabase
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

    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId != null) {
      _messagesRealtimeChannel ??= supabase
          .channel('public:messages:$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: currentUserId,
            ),
            callback: (payload) async {
              await _showIncomingMessageNotification(payload.newRecord);
            },
          )
          .subscribe();
    }
  }

  Future<void> _showIncomingMessageNotification(
    Map<String, dynamic> newRecord,
  ) async {
    if (!(await NotificationService.isEnabled())) return;

    final supabase = Supabase.instance.client;
    final senderId = newRecord['sender_id']?.toString() ?? '';
    final rawBody = newRecord['body']?.toString() ?? '';

    String title = 'New message';
    if (senderId.isNotEmpty) {
      try {
        final sender = await supabase
            .from('users')
            .select('name')
            .eq('id', senderId)
            .maybeSingle();
        if (sender != null && sender['name'] != null) {
          title = sender['name'].toString();
        }
      } catch (_) {}
    }

    String body;
    if (rawBody.startsWith('__img__::')) {
      body = 'sent a photo';
    } else if (rawBody.trim().isEmpty) {
      body = 'sent a message';
    } else {
      body = rawBody;
    }

    NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 1000000,
      title: title,
      body: body,
    );
  }

  void _stopSupabaseListener() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    if (_messagesRealtimeChannel != null) {
      Supabase.instance.client.removeChannel(_messagesRealtimeChannel!);
      _messagesRealtimeChannel = null;
    }
  }

  double _responsiveTextScale(MediaQueryData mediaQuery) {
    final shortestSide = mediaQuery.size.shortestSide;
    final screenScale = (shortestSide / 390).clamp(1.0, 1.2);
    final systemScale = mediaQuery.textScaler.scale(1.0);
    return (systemScale * screenScale).clamp(systemScale, 1.35);
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
            child: SafeArea(
              child: CustomSnackBar(
                message:
                    'No Internet Connection! \n Please check your network and try again',
              ),
            ),
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
    final isDark = themeProvider.effectiveBrightness == Brightness.dark;

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
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(_responsiveTextScale(mediaQuery)),
            ),
            child: child,
          );
        },
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
        themeMode: themeProvider.themeMode,
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
