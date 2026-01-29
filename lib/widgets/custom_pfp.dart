// lib/widgets/custom_pfp.dart
import '../core/imports.dart';

class CustomPfp extends StatelessWidget {
  final double dimentions;
  final double fontSize;
  final String? nameOverride; // Allows real-time updates from TextField

  const CustomPfp({
    super.key,
    required this.dimentions,
    required this.fontSize,
    this.nameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // Logic: Use the override if the user is typing, otherwise use the saved name
    final String displayName =
        nameOverride ?? userProvider.currentUser?.name ?? "?";

    // Extract initials safely
    String initials = "";
    if (displayName.trim().isNotEmpty) {
      List<String> parts = displayName.trim().split(" ");
      if (parts.length > 1) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Container(
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
    );
  }
}
