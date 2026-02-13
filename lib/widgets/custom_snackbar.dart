// ignore_for_file: deprecated_member_use

import '../core/imports.dart';

class CustomSnackBar extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final bool isSuccess; // New bool to handle icon logic

  const CustomSnackBar({
    super.key,
    required this.message,
    this.backgroundColor = AppColors.red,
    this.icon = Icons.info_outline_rounded,
    this.isSuccess = false, // Default to false
  });

  // Global static method to show the snackbar from anywhere
  static void show(
    BuildContext context,
    String message, {
    Color? color,
    IconData? icon,
    bool isSuccess = false, // Pass the bool through here
  }) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _TopSnackBarAnimator(
        onDismiss: () => overlayEntry.remove(),
        child: CustomSnackBar(
          message: message,
          // If color is null, default based on isSuccess
          backgroundColor: color ?? (isSuccess ? Colors.green : AppColors.red),
          icon:
              icon ??
              (isSuccess
                  ? Icons.check_circle_outline
                  : Icons.info_outline_rounded),
          isSuccess: isSuccess,
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final bool showTick =
        isSuccess || backgroundColor == AppColors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logic: Show different icon/container based on isSuccess
            SvgPicture.asset(
              showTick ? AppIcons.tick : AppIcons.info,
              color: Colors.white,
              width: 32,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Internal helper for the slide animation
class _TopSnackBarAnimator extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _TopSnackBarAnimator({required this.child, required this.onDismiss});

  @override
  State<_TopSnackBarAnimator> createState() => _TopSnackBarAnimatorState();
}

class _TopSnackBarAnimatorState extends State<_TopSnackBarAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _dismiss();
    });
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Dismissible(
            key: ValueKey(widget.hashCode),
            direction: DismissDirection.up,
            onDismissed: (_) => _dismiss(),
            child: Material(
              color: Colors.transparent,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
