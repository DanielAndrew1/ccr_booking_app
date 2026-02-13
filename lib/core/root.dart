import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/pages/login_page.dart';
import 'package:ccr_booking/pages/onboarding/onboarding_flow.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:ccr_booking/widgets/custom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _loadSeen();
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (_seenOnboarding == null) {
      return const Scaffold(body: Center(child: CustomLoader()));
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
