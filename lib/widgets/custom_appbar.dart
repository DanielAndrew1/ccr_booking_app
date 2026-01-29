// lib/widgets/custom_app_bar.dart
import '../core/imports.dart';

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
      child: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.lightcolor,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 80,
        elevation: 10,
        automaticallyImplyLeading: false,
        shadowColor: AppColors.primary,
        leading: hideLeading
            ? null
            : (showPfp
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Center(
                        child: CustomPfp(dimentions: 45, fontSize: 21),
                      ),
                    )
                  : IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: Icon(
                        Icons.adaptive.arrow_back_rounded,
                        color: Colors.white,
                      ),
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
                              style: const TextStyle(
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
