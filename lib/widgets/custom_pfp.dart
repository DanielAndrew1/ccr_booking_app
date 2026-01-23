// ignore_for_file: unnecessary_underscores


import 'package:ccr_booking/core/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import 'custom_navbar.dart';

class CustomPfp extends StatelessWidget {
  final Color? color; // Removed the assignment here
  final double dimentions;
  final double fontSize;

  const CustomPfp({
    super.key,
    required this.dimentions,
    required this.fontSize,
    this.color, // Added to constructor
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    final initials = _getInitials(currentUser.name);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const CustomNavbar(initialIndex: 3),
          ),
        );
      },
      child: Container(
        width: dimentions,
        height: dimentions,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Logic: Use provided color, otherwise default to AppColors.primary
          color: AppColors.primary,
        ),
        child: Text(
          initials,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
