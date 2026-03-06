// lib/widgets/custom_pfp.dart
// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/imports.dart';

class CustomPfp extends StatelessWidget {
  final double dimentions;
  final double fontSize;
  final String? nameOverride;
  final String? imageUrlOverride;
  final VoidCallback? onTapOverride;
  final bool disableTap;

  const CustomPfp({
    super.key,
    required this.dimentions,
    required this.fontSize,
    this.nameOverride,
    this.imageUrlOverride,
    this.onTapOverride,
    this.disableTap = false,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    // Use the provider to control the navbar index
    final navProvider = Provider.of<NavbarProvider>(context, listen: false);

    final String displayName =
        nameOverride ?? userProvider.currentUser?.name ?? "?";

    String initials = "";
    if (displayName.trim().isNotEmpty) {
      List<String> parts = displayName.trim().split(" ");
      if (parts.length > 1) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    final bool hasExplicitUserTarget =
        nameOverride != null || imageUrlOverride != null;
    final String? imageUrl = hasExplicitUserTarget
        ? imageUrlOverride
        : userProvider.currentUser?.avatarUrl;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: disableTap
          ? null
          : (onTapOverride ??
                () {
                  navProvider.setIndex(3);
                }),
      child: Container(
        width: dimentions,
        height: dimentions,
        decoration: BoxDecoration(
          gradient: AppColors.pfpGradient(isDark),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? ClipOval(
                  child: Image.network(
                    imageUrl,
                    width: dimentions,
                    height: dimentions,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Text(
                      initials,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : Text(
                  initials,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
