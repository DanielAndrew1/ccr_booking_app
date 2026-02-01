// ignore_for_file: deprecated_member_use

import '../core/imports.dart';

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Increased horizontal padding for better spacing from screen edges
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(
            50,
          ), // Slightly less rounded for multi-line
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withOpacity(0.5),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(AppIcons.info, color: Colors.white, width: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No internet connection!\nPlease check your network and try again.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2, // Tighter line height for 2 rows
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}
