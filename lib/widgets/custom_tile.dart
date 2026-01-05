// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class CustomTile extends StatelessWidget {
  final String title;
  final Widget? route;
  final IconData? icon;
  final bool overlayColor; // Changed to non-nullable bool
  final Widget? trailing;
  final VoidCallback? onTap;

  const CustomTile({
    super.key,
    required this.title,
    this.icon,
    this.route,
    this.trailing,
    this.onTap,
    this.overlayColor = true, // Set default to false
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 5),
        InkWell(
          // Logic: If overlayColor is false, make it transparent (no splash).
          // If true, we don't set it (null), letting it use the theme's default splash/highlight.
          overlayColor: overlayColor
              ? null // Uses default Material splash effect
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
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              // Added Center to keep ListTile aligned
              child: ListTile(
                leading: Icon(
                  icon,
                  color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing:
                    trailing ??
                    Icon(
                      Icons.adaptive.arrow_forward_rounded,
                      color: isDark ? Colors.white54 : const Color(0xFF2D2D2D),
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
