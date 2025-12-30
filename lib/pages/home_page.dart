import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../pages/login_page.dart';
import '../widgets/custom_pfp.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    // Detect if the app is in Dark Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(60),
          ),
          child: AppBar(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.lightcolor,
            toolbarHeight: 80,
            automaticallyImplyLeading: false,
            // Match the shadow color from CustomAppBar
            shadowColor: AppColors.primary,
            centerTitle: false,
            // Style Match: We remove the manual padding/centering to match CustomAppBar's 'leading' behavior
            leading: const CustomPfp(dimentions: 60, fontSize: 24),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hello, ${currentUser.name.split(' ').first}',
                  style: AppFontStyle.subTitleMedium().copyWith(
                    color: AppColors.lightcolor,
                  ),
                ),
                Text(
                  'Manage everything in a few clicks',
                  style: AppFontStyle.textRegular().copyWith(
                    color: AppColors.lightcolor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primary : AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              NotificationService().showNotification(
                title: "Test",
                body: "This is to test if the notification service works",
              );
            },
            child: const Text("Receive Notification"),
          ),
        ),
      ),
    );
  }
}
