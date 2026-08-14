import 'package:site_lapse/core/imports.dart';

class CustomTextfield extends StatefulWidget {
  final TextEditingController textEditingController;
  final TextInputType keyboardType;
  final bool? isObsecure;
  final String? labelText;
  final String? hintText;
  final TextCapitalization textCapitalization;

  const CustomTextfield({
    super.key,
    required this.textEditingController,
    required this.keyboardType,
    this.isObsecure = false,
    this.labelText,
    this.hintText,
    required this.textCapitalization,
  });

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isObsecure ?? false;
  }

  @override
  void didUpdateWidget(covariant CustomTextfield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isObsecure != widget.isObsecure) {
      _obscureText = widget.isObsecure ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDarkMode;

    // Set colors based on Dark Mode state
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color hintColor = isDark ? Colors.white60 : Colors.black54;
    final Color inactiveUnderlineColor = isDark
        ? Colors.white60
        : Colors.black26;

    final isPassword = widget.isObsecure ?? false;
    return TextFormField(
      controller: widget.textEditingController,
      keyboardType: widget.keyboardType,
      obscureText: isPassword && _obscureText,
      textCapitalization: widget.textCapitalization,
      cursorColor: AppColors.primary,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
      scrollPadding: const EdgeInsets.only(bottom: 120),

      // This controls the input text color
      style: TextStyle(color: textColor),

      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: isPassword
            ? IconButton(
                tooltip: _obscureText ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureText = !_obscureText),
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: hintColor,
                ),
              )
            : null,

        // This controls the hint text color
        hintStyle: TextStyle(color: hintColor),

        // Label color when not focused
        labelStyle: TextStyle(color: hintColor),

        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),

        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: inactiveUnderlineColor, width: 2),
        ),

        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),
    );
  }
}
