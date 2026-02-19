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
  bool _internalLoading = false;

  Future<void> _handlePress() async {
    if (widget.onPressed == null || _internalLoading) return;
    setState(() => _internalLoading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _internalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final effectiveColor = widget.color ?? WidgetStateProperty.all(AppColors.primary);

    // Determine if we are loading (externally via null onPressed or internally)
    final bool isLoading = widget.onPressed == null || _internalLoading;

    // Helper to get text even if passed as a child
    String buttonText = widget.text ?? '';
    Text? childText;
    if (widget.child is Text) {
      childText = widget.child as Text;
      if (buttonText.isEmpty) {
        buttonText = childText.data ?? '';
      }
    }
    buttonText = loc.tr(buttonText);

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ElevatedButton(
        // If external logic says null, it's likely already loading/disabled
        onPressed: isLoading ? null : _handlePress,
        style: ButtonStyle(
          backgroundColor: effectiveColor,
          foregroundColor: WidgetStateProperty.all(
            Colors.black,
          ), // Black for visibility on yellow
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          elevation: WidgetStateProperty.all(0),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomLoader(size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    buttonText,
                    style: AppFontStyle.textMedium().copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : (widget.child is Text
                ? Text(
                    buttonText,
                    style: (childText?.style ??
                            AppFontStyle.textMedium().copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ))
                        .copyWith(color: Colors.white),
                  )
                : widget.child ??
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.imagePath != null || widget.icon != null) ...[
                          IconHandler.buildIcon(
                            imagePath: widget.imagePath,
                            icon: widget.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          buttonText,
                          style: AppFontStyle.textMedium().copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )),
      ),
    );
  }
}
