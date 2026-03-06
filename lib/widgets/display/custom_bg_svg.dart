// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/imports.dart';

class CustomBgSvg extends StatelessWidget {
  const CustomBgSvg({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Positioned(
      top: 0,
      right: 0,
      child: SvgPicture.asset(
        AppIcons.bg,
        width: 250,
        color: isDark ? AppColors.primary : AppColors.secondary,
      ),
    );
  }
}
