import 'package:flutter/cupertino.dart';
import 'package:ccr_booking/core/imports.dart';

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
    final isDark = context.isDarkMode;

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
