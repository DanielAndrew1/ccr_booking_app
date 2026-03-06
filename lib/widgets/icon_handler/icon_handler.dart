import 'package:ccr_booking/core/imports.dart';

abstract class IconHandler {
  static Widget buildIcon({
    String? imagePath,
    IconData? icon,
    Color? color,
    double size = 24,
    bool isAdd = false,
    bool isDark = true,
  }) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.toLowerCase().contains('.svg')) {
        return SvgPicture.asset(
          imagePath,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(
            color ?? (isDark ? Colors.white : Colors.black),
            BlendMode.srcIn,
          ),
          // THIS PREVENTS THE CRASH:
          placeholderBuilder: (context) =>
              Icon(icon ?? Icons.broken_image, color: color, size: size),
        );
      } else {
        return Image.asset(
          imagePath,
          width: size,
          height: size,
          color: color,
          // FALLBACK FOR REGULAR IMAGES:
          errorBuilder: (context, error, stackTrace) =>
              Icon(icon ?? Icons.broken_image, color: color, size: size),
        );
      }
    }
    return Icon(icon ?? Icons.help_outline, color: color, size: size);
  }
}
