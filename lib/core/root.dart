import 'package:site_lapse/core/imports.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/onboarding/onboarding_flow.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool? _seenOnboarding;
  bool? _hasInternet;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadSeen();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectivity,
    );
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    if (mounted) {
      setState(() => _seenOnboarding = seen);
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      setState(() => _seenOnboarding = true);
    }
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    await _updateConnectivity(result);
  }

  Future<void> _updateConnectivity(List<ConnectivityResult> result) async {
    final hasInternet =
        !result.contains(ConnectivityResult.none) && await _canReachInternet();
    if (!mounted) return;
    setState(() {
      _hasInternet = hasInternet;
    });
  }

  Future<bool> _canReachInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (_seenOnboarding == null || _hasInternet == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    if (_hasInternet == false) {
      return NoInternetPage(onRetry: _initConnectivity);
    }

    if (_seenOnboarding == false) {
      return OnboardingFlow(onFinished: _finishOnboarding);
    }

    if (userProvider.currentUser == null) {
      return const LoginPage();
    }

    return CustomNavbar();
  }
}
