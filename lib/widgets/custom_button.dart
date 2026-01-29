// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import '../core/imports.dart';

class CustomButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final double height;
  final String? text;
  final Widget? child;
  final IconData? icon;
  final String? imagePath;
  final WidgetStateProperty<Color>? color;

  const CustomButton({
    super.key,
    required this.onPressed,
    this.height = 45,
    this.text,
    this.child,
    this.icon,
    this.imagePath,
    this.color,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _loading = false;

  Future<void> _handlePress() async {
    if (widget.onPressed == null || _loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final effectiveColor =
        widget.color ??
        WidgetStateProperty.all(
          isDark ? AppColors.primary : AppColors.secondary,
        );

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ElevatedButton(
        onPressed: _loading ? null : _handlePress,
        style: ButtonStyle(
          backgroundColor: effectiveColor,
          foregroundColor: WidgetStateProperty.all(AppColors.lightcolor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          elevation: WidgetStateProperty.all(0),
        ),
        child: _loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomLoader(size: 22, strokeWidth: 2),
                  const SizedBox(width: 6),
                  Text(
                    widget.text ?? '',
                    style: AppFontStyle.textMedium().copyWith(
                      color: AppColors.lightcolor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : widget.child ??
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.imagePath != null || widget.icon != null) ...[
                        IconHandler.buildIcon(
                          imagePath: widget.imagePath,
                          icon: widget.icon,
                          color: AppColors.lightcolor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text ?? '',
                        style: AppFontStyle.textMedium().copyWith(
                          color: AppColors.lightcolor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
