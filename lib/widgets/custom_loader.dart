import 'dart:io';
import 'package:ccr_booking/core/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';

class CustomLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const CustomLoader({
    super.key,
    this.size = 34,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Determine the color: use the passed color if it exists,
    // otherwise fall back to the dark/light mode logic.
    final Color effectiveColor =
        color ?? (isDark ? AppColors.primary : AppColors.secondary);

    if (Platform.isIOS) {
      return CupertinoActivityIndicator(
        radius: size / 2,
        color: effectiveColor,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: effectiveColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}
