import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_pfp.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String text;
  final bool showPfp; // Changed to final to fix linting warning
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.text,
    required this.showPfp,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(60)),
      child: AppBar(
        // Theming logic for AppBar background
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.lightcolor,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        shadowColor: AppColors.primary,
        leading: showPfp
            ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CustomPfp(
                  dimentions: 60,
                  fontSize: 24,
                ),
            )
            : IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.adaptive.arrow_back_rounded),
              ),
        centerTitle: true,
        title: Text(
          text,
          style: AppFontStyle.titleMedium().copyWith(color: Colors.white),
        ),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
