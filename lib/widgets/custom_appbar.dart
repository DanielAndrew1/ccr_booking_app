import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart'; // Import for ThemeProvider
import 'package:ccr_booking/widgets/custom_pfp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String text;
  final bool showPfp;
  final List<Widget>? actions;
  final bool hideLeading;
  final VoidCallback? onTodayPressed;

  const CustomAppBar({
    super.key,
    required this.text,
    required this.showPfp,
    this.actions,
    this.hideLeading = false,
    this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Detect the app theme
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
      child: AppBar(
        // --- THE FIX ---
        // We set the status bar style here dynamically based on the app's theme
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // If App is Dark -> Use Light Icons. If App is Light -> Use Dark Icons.
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          // Required for iOS to flip text color
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.lightcolor,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        shadowColor: AppColors.primary,
        leading: hideLeading
            ? null
            : (showPfp
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: CustomPfp(dimentions: 45, fontSize: 21),
                    )
                  : IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.adaptive.arrow_back_rounded),
                    )),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppFontStyle.titleMedium().copyWith(color: Colors.white),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: onTodayPressed != null
                  ? GestureDetector(
                      onTap: onTodayPressed,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 60,
                          height: 25,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Center(
                            child: Text(
                              "Today",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
