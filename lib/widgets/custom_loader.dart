import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class CustomLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const CustomLoader({super.key, this.size = 34, this.strokeWidth = 2});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (Platform.isIOS) {
      return CupertinoActivityIndicator(
        radius: size / 2,
        color: isDark ? AppColors.secondary : AppColors.primary,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: isDark ? AppColors.secondary : AppColors.primary,
        strokeWidth: strokeWidth,
      ),
    );
  }
}
