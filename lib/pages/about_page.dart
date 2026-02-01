import 'package:ccr_booking/core/app_version_plus.dart';
import 'package:ccr_booking/core/imports.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(text: 'About Us', showPfp: false),
      body: Stack(
        children: [
          // Background SVG positioned to match HomePage/ClientsPage
          const CustomBgSvg(),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Logo or Icon Placeholder
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        "assets/icon.png",
                        width: 90,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Title Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "CCR Booking System",
                        style: AppFontStyle.subTitleBold().copyWith(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "App Version: ${AppVersionPlus.appVersion}",
                        style: AppFontStyle.textRegular().copyWith(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Mission Section
                  _buildSectionTitle("Our Mission", isDark),
                  const SizedBox(height: 12),
                  _buildDescriptionText(
                    '''To advance the photographic and cinematic dreams of our customers by delivering superior, cutting-edge gear and providing exceptional customer service. Rent, shoot, return - it's as easy as that. You choose what you want, when you want to pick it up, and for how long you want to rent it for. Our entire rental process is done completely through our app but if you ever have a special request you can call us and talk to a person working at our office.''',
                    isDark,
                  ),
                  const SizedBox(height: 18),
                  _buildSectionTitle("Our Humble Beginnings", isDark),
                  const SizedBox(height: 12),
                  _buildDescriptionText(
                    '''Starting with just a handful of lenses in 2012, -Andrew Emil- set out to make gear more affordable through rentals. As word spread about our services, Andrew made every effort to hire great, local talent who are dedicated to great customer service and deeply passionate about photography and videography. For years since, customers have entrusted the CCR team to provide an ever growing selection of cameras, lenses, lighting kits, audio equipment, and production support systems that are suitable for both novices and pros. The most important element of our success has always been our dedicated, passionate, and loyal customers, who we consider to all be “silent partners” of CairoCameraRentals.com. We have been entrusted by our customers to take us along with them on their photographic and cinematic journey.''',
                    isDark,
                  ),

                  const SizedBox(height: 30),

                  // Features Section
                  _buildSectionTitle("Key Features", isDark),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.check_circle_outline,
                    "Real-time Booking Tracking",
                    isDark,
                  ),
                  _buildFeatureItem(
                    Icons.check_circle_outline,
                    "Inventory & Product Management",
                    isDark,
                  ),
                  _buildFeatureItem(
                    Icons.check_circle_outline,
                    "Automated Revenue Analytics",
                    isDark,
                  ),
                  _buildFeatureItem(
                    Icons.check_circle_outline,
                    "Role-based Access Control",
                    isDark,
                  ),

                  const SizedBox(height: 40),

                  // Contact/Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2C).withOpacity(0.7)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Need Support?",
                          style: AppFontStyle.subTitleMedium().copyWith(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Contact us at support@ccrbooking.com",
                          style: AppFontStyle.textRegular().copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 100,
                  ), // Space for bottom navigation if applicable
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: AppFontStyle.subTitleBold().copyWith(
        color: AppColors.primary,
        fontSize: 18,
      ),
    );
  }

  Widget _buildDescriptionText(String text, bool isDark) {
    return Text(
      text,
      style: AppFontStyle.textRegular().copyWith(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppFontStyle.textRegular().copyWith(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
