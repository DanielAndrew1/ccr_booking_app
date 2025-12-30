import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:flutter/material.dart';

class CustomProductTile extends StatelessWidget {
  final String title;
  final num price;
  final Widget route;
  final String? imageUrl;

  const CustomProductTile({
    super.key,
    required this.title,
    required this.route,
    this.imageUrl,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    // Detect dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 5),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => route),
          ),
          child: Container(
            decoration: BoxDecoration(
              // Background color based on theme
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isDark
                  ? Border.all(color: Colors.white.withOpacity(0.05))
                  : null,
              boxShadow: isDark
                  ? [] // Avoid glowing shadows in dark mode
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CustomLoader(size: 18));
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.primary,
                              ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.primary,
                        ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      // Toggle text color
                      color: isDark ? Colors.white : AppColors.darkbg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "${price.toInt()} EGP/Day",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }
}
