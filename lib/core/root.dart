import 'package:site_lapse/core/imports.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool? _hasInternet;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectivity,
    );
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

    if (_hasInternet == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    if (_hasInternet == false) {
      return NoInternetPage(onRetry: _initConnectivity);
    }

    if (userProvider.currentUser == null) {
      return const LoginPage();
    }

    return CustomNavbar();
  }
}
