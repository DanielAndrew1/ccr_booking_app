import 'package:flutter/material.dart';
import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';

class CustomButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final String? text;
  final Widget? child;
  final IconData? icon;
  final WidgetStateProperty<Color>? color;

  const CustomButton({
    super.key,
    required this.onPressed,
    this.text,
    this.child,
    this.icon,
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Logic: If widget.color is null, check isDark
    final WidgetStateProperty<Color> effectiveColor =
        widget.color ??
        WidgetStateProperty.all(
          isDark ? AppColors.primary : AppColors.secondary,
        );

    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _loading ? null : _handlePress,
        style: ButtonStyle(
          backgroundColor: effectiveColor,
          foregroundColor: WidgetStateProperty.all(AppColors.lightcolor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        child: _loading
            ? const CustomLoader(size: 22, strokeWidth: 2)
            : widget.child ??
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 22),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        widget.text ?? '',
                        style: AppFontStyle.textMedium().copyWith(
                          color: AppColors.lightcolor,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
