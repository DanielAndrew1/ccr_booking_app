// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class CustomBgSvg extends StatelessWidget {
  const CustomBgSvg({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    return Positioned(
      top: 0,
      right: 0,
      child: SvgPicture.asset(
        'assets/bg-decoration.svg',
        width: 250,
        color: isDark ? AppColors.primary : AppColors.secondary,
      ),
    );
  }
}
