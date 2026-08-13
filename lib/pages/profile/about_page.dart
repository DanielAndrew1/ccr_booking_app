// ignore_for_file: deprecated_member_use, no_leading_underscores_for_local_identifiers

import 'package:site_lapse/core/imports.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(text: 'About Us', showPfp: false),
      body: Stack(
        children: [
          // Background SVG positioned to match HomePage/ClientsPage
          const CustomBgSvg(),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Logo or Icon Placeholder
                  Center(
                    child: Image.asset(
                      AppImages.darkIcon,
                      width: 100,
                      height: 100,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Title Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Site Lapse",
                        style: AppFontStyle.subTitleBold().copyWith(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<String>(
                    future: AppVersionPlus.appVersion(),
                    builder: (context, snapshot) {
                      final version = snapshot.data ?? "...";
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "App Version $version",
                            style: AppFontStyle.textRegular().copyWith(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
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
                    '''Site Lapse helps teams manage installation projects, connected cameras, subscriptions, payments, and client communication in one clear workspace.''',
                    isDark,
                  ),

                  const SizedBox(height: 30),

                  // Features Section
                  _buildSectionTitle("Key Features", isDark),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    context,
                    "Real-time Project Tracking",
                    isDark,
                  ),
                  _buildFeatureItem(
                    context,
                    "Inventory & Product Management",
                    isDark,
                  ),
                  _buildFeatureItem(
                    context,
                    "Automated Revenue Analytics",
                    isDark,
                  ),
                  _buildFeatureItem(
                    context,
                    "Role-based Access Control",
                    isDark,
                  ),
                  _buildFeatureItem(
                    context,
                    "Messages for improved communication",
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            "Contact us at:",
                            style: AppFontStyle.textRegular().copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildContactRow(
                          AppIcons.phone,
                          "+20 1282040613",
                          isDark,
                        ),
                        _buildContactRow(
                          AppIcons.email,
                          "info@site-lapse.com",
                          isDark,
                        ),
                        _buildContactRow(
                          AppIcons.globe,
                          "www.site-lapse.com",
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 50),
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

  Widget _buildFeatureItem(BuildContext context, String text, bool isDark) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SvgPicture.asset(AppIcons.tick, width: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            loc.tr(text),
            style: AppFontStyle.textRegular().copyWith(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(String iconPath, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SvgPicture.asset(
            iconPath,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              isDark ? Colors.white70 : Colors.black54,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppFontStyle.textRegular().copyWith(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
