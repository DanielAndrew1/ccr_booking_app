// lib/widgets/custom_pfp.dart
// ignore_for_file: deprecated_member_use

import '../core/imports.dart';

class CustomPfp extends StatelessWidget {
  final double dimentions;
  final double fontSize;
  final String? nameOverride;

  const CustomPfp({
    super.key,
    required this.dimentions,
    required this.fontSize,
    this.nameOverride,
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

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Correct way: Tell the provider to switch to index 4 (Add Booking)
        navProvider.setIndex(4);
      },
      child: Container(
        width: dimentions,
        height: dimentions,
        decoration: BoxDecoration(
          color: AppColors.primary,
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
          child: Text(
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
