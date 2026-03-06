import 'dart:ui' as ui;

import 'package:ccr_booking/core/imports.dart';

class SplashOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const SplashOverlay({super.key, required this.onAnimationComplete});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late AnimationController _revealController;
  late AnimationController _pulseController;

  late Animation<double> _cropAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseAnimation;

  bool _isDataReady = false;
  bool _isPulsing = true;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _cropAnimation = Tween<double>(begin: 1.0, end: 0.45).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.6, 1.0, curve: Curves.linear),
      ),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _startSequence();
  }

  Future<void> _waitForInitialData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(
      context,
      listen: false,
    );
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    await localeProvider.load();
    await userProvider.loadUser();

    if (userProvider.currentUser != null) {
      await bookingProvider.fetchAllBookings();
    }

    await Connectivity().checkConnectivity();
  }

  Future<void> _startSequence() async {
    await _waitForInitialData();
    if (!mounted) return;

    _pulseController.stop(canceled: false);
    setState(() => _isPulsing = false);

    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    setState(() => _isDataReady = true);
    await _revealController.forward();

    if (!mounted) return;
    widget.onAnimationComplete();
  }

  Widget _buildLogoWithGlow(bool isDark) {
    final pulse = _isPulsing ? _pulseAnimation.value : 0.0;
    final logoWidth = MediaQuery.of(context).size.width.clamp(260.0, 420.0);
    final sigmaInner = 6 + (pulse * 10);
    final outerOpacity = (isDark ? 0.80 : 0.66) + (pulse * 0.16);
    final innerOpacity = (isDark ? 0.55 : 0.45) + (pulse * 0.12);

    return Transform.scale(
      scale: _isDataReady ? _scaleAnimation.value : 1,
      child: ClipRRect(
        borderRadius: BorderRadiusGeometry.circular(100),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: _isDataReady ? _cropAnimation.value : 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Opacity(
                  opacity: outerOpacity,
                  child: 
                  Image.asset(
                      AppImages.logo,
                      width: logoWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              IgnorePointer(
                child: Opacity(
                  opacity: innerOpacity,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: sigmaInner,
                      sigmaY: sigmaInner,
                    ),
                    child: Image.asset(
                      AppImages.logo,
                      width: logoWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              Image.asset(
                AppImages.logo,
                width: logoWidth,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AnimatedBuilder(
      animation: Listenable.merge([_revealController, _pulseController]),
      builder: (context, child) {
        return Opacity(
          opacity: _isDataReady ? _opacityAnimation.value : 1.0,
          child: Container(
            color: isDark ? AppColors.darkbg : AppColors.lightcolor,
            child: Center(child: _buildLogoWithGlow(isDark)),
          ),
        );
      },
    );
  }
}
