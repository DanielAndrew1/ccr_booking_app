// ignore_for_file: deprecated_member_use, dead_code
import '../core/imports.dart';

class CustomTile extends StatelessWidget {
  final String title;
  final Widget? route;
  final IconData? icon;
  final String? imagePath;
  final bool overlayColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
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
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = color ?? (isDark ? const Color(0xFF2D2D2D) : Colors.white);
    final contentColor = textColor ?? (isDark ? Colors.white : Colors.black);
    final iconContainerColor = textColor != null ? textColor!.withOpacity(0.2) : Colors.grey.withOpacity(0.25);

    return Column(
      children: [
        const SizedBox(height: 5),
        InkWell(
          overlayColor: overlayColor
              ? WidgetStateProperty.all(Colors.grey)
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
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconContainerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconHandler.buildIcon(
                  imagePath: imagePath,
                  icon: icon,
                  color: contentColor,
                  size: 20,
                ),
              ),
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
                    Icons.arrow_forward_ios_rounded,
                    color: contentColor,
                    size: 20,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
