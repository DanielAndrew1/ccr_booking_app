import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_pfp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String text;
  final bool showPfp;
  final List<Widget>? actions;
  final bool hideLeading;
  final VoidCallback? onTodayPressed; // Added for Calendar reset

  const CustomAppBar({
    super.key,
    required this.text,
    required this.showPfp,
    this.actions,
    this.hideLeading = false,
    this.onTodayPressed, // Added for Calendar reset
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
        child: AppBar(
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
                        child: CustomPfp(
                          dimentions: 45,
                          fontSize: 21,
                        ), // Slightly smaller for 80 height
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
              // Animated "Today" button under the text
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
                              borderRadius: BorderRadius.circular(50)
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
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
