// ignore_for_file: deprecated_member_use, dead_code
import 'package:ccr_booking/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CustomTile extends StatelessWidget {
  final String title;
  final Widget? route;
  final IconData? icon;
  final bool overlayColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color; // Added color parameter
  final Color? textColor; // Added text/icon color parameter

  const CustomTile({
    super.key,
    required this.title,
    this.icon,
    this.route,
    this.trailing,
    this.onTap,
    this.overlayColor = true,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Default background: color if provided, else dark color or WHITE
    final bgColor = color ?? (isDark ? const Color(0xFF2D2D2D) : Colors.white);

    // Default text/icon: textColor if provided, else white or dark grey
    final contentColor =
        textColor ?? (isDark ? Colors.white : const Color(0xFF2D2D2D));

    return Column(
      children: [
        const SizedBox(height: 5),
        InkWell(
          overlayColor: overlayColor
              ? null
              : WidgetStateProperty.all(Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          onTap:
              onTap ??
              () {
                if (route != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => route!),
                  );
                }
              },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: ListTile(
                leading: Icon(icon, color: contentColor),
                title: Text(
                  title,
                  style: TextStyle(
                    color: contentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing:
                    trailing ??
                    Icon(
                      Icons.adaptive.arrow_forward_rounded,
                      color: contentColor,
                      size: 20,
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }
}
