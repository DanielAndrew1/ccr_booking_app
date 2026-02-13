import '../../core/imports.dart';

class OnboardingTwo extends StatelessWidget {
  const OnboardingTwo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Skip",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  AppImages.onBoarding2,
                  width: 400,
                ),
                const SizedBox(height: 24),
                Text(
                  "Track Bookings in Real-Time",
                  textAlign: TextAlign.center,
                  style: AppFontStyle.subTitleBold().copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Stay updated with instant status changes, pickup and return reminders, and live inventory availability.",
                  textAlign: TextAlign.center,
                  style: AppFontStyle.textRegular().copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
