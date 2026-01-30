// ignore_for_file: deprecated_member_use

import '../core/imports.dart';

class CustomSnackBar extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;

  const CustomSnackBar({
    super.key,
    required this.message,
    this.backgroundColor = AppColors.red,
    this.icon = Icons.info_outline_rounded,
  });

  // Global static method to show the snackbar from anywhere
  static void show(
    BuildContext context,
    String message, {
    Color? color,
    IconData? icon,
  }) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _TopSnackBarAnimator(
        onDismiss: () => overlayEntry.remove(),
        child: CustomSnackBar(
          message: message,
          backgroundColor: color ?? AppColors.red,
          icon: icon ?? Icons.info_outline_rounded,
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: backgroundColor,
              blurRadius: 12,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset(0, 0.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
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
          child: Material(color: Colors.transparent, child: widget.child),
        ),
      ),
    );
  }
}
