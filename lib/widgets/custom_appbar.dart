import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_pfp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String text;
  final bool showPfp;
  final List<Widget>? actions;
  final bool hideLeading;

  const CustomAppBar({
    super.key,
    required this.text,
    required this.showPfp,
    this.actions,
    this.hideLeading = false,
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
                        child: CustomPfp(dimentions: 65, fontSize: 21),
                      )
                    : IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.adaptive.arrow_back_rounded),
                      )),
          centerTitle: true,
          title: Text(
            text,
            style: AppFontStyle.titleMedium().copyWith(color: Colors.white),
          ),
          actions: actions,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
