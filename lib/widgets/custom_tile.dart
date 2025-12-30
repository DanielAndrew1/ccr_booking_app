import 'package:ccr_booking/core/app_theme.dart';
import 'package:flutter/material.dart';

class CustomTile extends StatelessWidget {
  final String title;
  final Widget? route; // Made optional
  final IconData? icon;
  final Widget? trailing; // Added to allow the Switch
  final VoidCallback? onTap; // Added for custom actions

  const CustomTile({
    super.key,
    required this.title,
    this.icon,
    this.route,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 5),
        InkWell(
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
              // Dynamic background: Surface color changes based on theme
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: Colors.white10) : null,
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ListTile(
              leading: Icon(
                icon,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.darkbg,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing:
                  trailing ??
                  Icon(
                    Icons.adaptive.arrow_forward_rounded,
                    color: isDark ? Colors.white54 : AppColors.darkbg,
                    size: 20,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }
}
