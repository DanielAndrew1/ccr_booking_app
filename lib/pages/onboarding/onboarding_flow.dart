// ignore_for_file: deprecated_member_use

import '../../core/imports.dart';
import 'onboarding_1.dart';
import 'onboarding_2.dart';

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingFlow({super.key, required this.onFinished});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex == 1) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : Colors.white,
      body: Stack(
        children: [
          const CustomBgSvg(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    children: [
                      _buildAnimatedPage(0, const OnboardingOne()),
                      _buildAnimatedPage(1, const OnboardingTwo()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: _next,
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: (_currentIndex + 1) / 2,
                              ),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return Transform.rotate(
                                  angle: 3.141592653589793,
                                  child: CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 2,
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.2),
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.adaptive.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPage(int index, Widget child) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        double page = _currentIndex.toDouble();
        if (_controller.hasClients) {
          try {
            page = _controller.page ?? _currentIndex.toDouble();
          } catch (_) {
            page = _currentIndex.toDouble();
          }
        }
        final delta = (page - index).abs().clamp(0.0, 1.0);
        final scale = 1 - (delta * 0.04);
        final opacity = 1 - (delta * 0.25);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
