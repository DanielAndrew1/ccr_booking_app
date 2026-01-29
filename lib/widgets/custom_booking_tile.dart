import '../core/imports.dart';

class CustomBookingTile extends StatelessWidget {
  final String productName;

  const CustomBookingTile({super.key, required this.productName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 5),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.darkbg,
              ),
              title: Text(
                productName,
                style: const TextStyle(
                  color: AppColors.darkbg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppColors.darkbg,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }
}
