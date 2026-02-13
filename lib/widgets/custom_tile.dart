// ignore_for_file: deprecated_member_use, dead_code, unrelated_type_equality_checks
import '../core/imports.dart';

class CustomTile extends StatelessWidget {
  final String title;
  final Widget? route;
  final IconData? icon;
  final String? imagePath;
  final bool overlayColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const CustomTile({
    super.key,
    required this.title,
    this.icon,
    this.imagePath,
    this.route,
    this.trailing,
    this.onTap,
    this.overlayColor = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor =
        isDark ? Color(0xFF2D2D2D).withOpacity(0.6) : Colors.white.withOpacity(0.6);
    final contentColor = textColor ?? (isDark ? Colors.white : Colors.black);
    final iconContainerColor =
        textColor != null ? textColor!.withOpacity(0.13) : Colors.grey.withOpacity(0.13);
    final overlayTint = textColor != null
        ? textColor!.withOpacity(0.2)
        : Colors.grey.withOpacity(0.05);

    return Column(
      children: [
        const SizedBox(height: 5),
        Material(
          color: Colors.transparent,
          child: InkWell(
            overlayColor: overlayColor
                ? WidgetStateProperty.all(overlayTint)
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
            child: Ink(
              height: 57,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconHandler.buildIcon(
                    imagePath: imagePath,
                    icon: icon,
                    color: contentColor,
                    size: 26,
                  ),
                ),
                title: Text(
                  loc.tr(title),
                  style: TextStyle(
                    color: contentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing:
                    trailing ??
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: contentColor,
                      size: 20,
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
