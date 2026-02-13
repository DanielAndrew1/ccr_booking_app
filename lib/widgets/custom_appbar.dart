// lib/widgets/custom_app_bar.dart
// ignore_for_file: deprecated_member_use

import '../core/imports.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? text;
  final Widget? child;
  final bool showPfp;
  final List<Widget>? actions;
  final bool hideLeading;
  final VoidCallback? onTodayPressed;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingPressed;

  const CustomAppBar({
    super.key,
    this.text,
    required this.showPfp,
    this.actions,
    this.hideLeading = false,
    this.onTodayPressed,
    this.leadingIcon,
    this.onLeadingPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final loc = AppLocalizations.of(context);
    final Widget titleWidget = child ??
        (text == null
            ? const SizedBox.shrink()
            : Text(
                loc.tr(text ?? ''),
                style: AppFontStyle.titleMedium().copyWith(
                  color: Colors.white,
                ),
              ));

    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      backgroundColor: isDark ? AppColors.secondary : AppColors.primary,
      foregroundColor: AppColors.lightcolor,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 80,
      elevation: 10,
      automaticallyImplyLeading: false,
      leading: hideLeading
          ? null
          : (leadingIcon != null || onLeadingPressed != null
                ? IconButton(
                    onPressed:
                        onLeadingPressed ?? () => Navigator.maybePop(context),
                    icon: Icon(
                      leadingIcon ?? Icons.adaptive.arrow_back_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  )
                : (showPfp
                      ? Padding(
                          padding: const EdgeInsets.only(left: 12,),
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
                        ))),
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          titleWidget,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: onTodayPressed != null
                ? GestureDetector(
                    onTap: onTodayPressed,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 70,
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Center(
                          child: Text(
                            loc.tr("Today"),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
